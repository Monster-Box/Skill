# OpenTele 内部机制

基于 `opentele` 1.15.1（源码 commit `9e18947`）实际阅读整理，非文档转述。

- 仓库：`github.com/thedemons/opentele`（MIT，470 stars）
- 最后提交：**2024-07-15**（已停更）
- 包结构：`src/api.py`（API 模板与设备生成）、`src/devices.py`（设备表）、`src/tl/telethon.py`（Telethon 集成）、`src/td/`（tdata 转换）

## 一、`Generate()` 的真实语义

### 哈希种子

`devices.py` 里 `SystemInfo._strtohashid`：

```python
byteid = os.urandom(32) if unique_id == None else unique_id.encode("utf-8")
return int(hashlib.sha1(byteid).hexdigest(), 16) % (10 ** 12)
```

结论：

- `unique_id` 非空 → 哈希确定 → **同一 `unique_id` 永远得到同一设备**，跨进程、跨机器、跨时间
- `unique_id is None` → `os.urandom(32)` → **每次调用都是新的随机值**

这就是「为什么有些代码要循环一百次重摇设备」的答案，也是「传 `unique_id` 就不用摇」的答案。

### 只随机两个字段

`Generate()` 的实现最终是：

```python
return cls(device_model=deviceInfo.model, system_version=deviceInfo.version)
```

**只有 `device_model` 和 `system_version` 被写入。** `app_version`、`lang_code`、`system_lang_code`、`lang_pack` 全部沿用类属性默认值。

### TelegramDesktop 的系统选择

```python
@classmethod
def Generate(cls, system: str = None, unique_id: str = None) -> _T:
    validList = ["windows", "macos", "linux"]
    if system == None or system not in validList:
        system = SystemInfo._hashtovalue(SystemInfo._strtohashid(unique_id), validList)
    ...
```

- 传了合法 `system` → 按你指定的来
- 没传或传了非法值 → 同样由 `unique_id` 哈希决定，**受同一随机性影响**
- **显式传 `system`** 是唯一可控的写法

### 各模板的实现分支

```python
if cls == API.TelegramAndroid or cls == API.TelegramAndroidX:
    deviceInfo = AndroidDevice.RandomDevice(unique_id)
elif cls == API.TelegramIOS:
    deviceInfo = iOSDeivce.RandomDevice(unique_id)
elif cls == API.TelegramMacOS:
    deviceInfo = macOSDevice.RandomDevice(unique_id)
else:
    raise NotImplementedError(f"{cls.__name__} device not supported for randomize yet")
```

浏览器系模板（`TelegramWeb_K` / `TelegramWeb_Z` / `Webogram`）走 `else` 分支，**直接抛 `NotImplementedError`**。

### 设备表规模

`devices.py` 中 `GeneralDesktopDevice` 的注释标注设备表更新于 2022-01-10；`WindowsDevice.deviceList` 实测有 **3160** 条主板/整机型号。

## 二、`pid` 到底去哪了

这是最容易误解的一处。`APIData` 在元类阶段会分配一个 `pid`：

```python
@classmethod
def _makePIDEnsure(cls) -> int:
    while True:
        pid = int.from_bytes(os.urandom(8), "little")
        if cls.findData(pid) == None:
            break
    return pid

@classmethod
def _clsMakePID(cls):
    cls.pid = cls._makePIDEnsure()
    cls.CustomInitConnectionList.append(cls)
```

**`pid` 是随机的、每实例不同的**。但它**不会发到 Telegram**，传递链路如下：

1. 构造客户端时，把 `pid` **冒充** `device_model` 塞进 Telethon 参数：

```python
# tl/telethon.py
kwargs["device_model"] = api.pid   # pass our hook id through the device_model
```

2. 真正发起 `initConnection` 时，用这个冒牌 `device_model`（其实是 pid）反查回真正的 `APIData`，再换回真实字段：

```python
# tl/telethon.py — CustomInitConnectionRequest.__init__
data = APIData.findData(device_model)   # 这里的 device_model 其实是 pid
if data != None:
    self.device_model = data.device_model if data.device_model else device_model
    self.app_version  = data.app_version  if data.app_version  else app_version
    ...  # 其余字段同理
    data.destroy()
else:
    self.device_model = device_model     # ← 查不到时，pid 会被当设备名发出去
```

**所以：`pid` 是纯进程内句柄。把它记进 JSON 毫无意义，读回来也不产生任何效果。**

顺带两个后果：

- **查不到就发 pid**：如果 `APIData` 没在 `CustomInitConnectionList` 里注册（极罕见），发出去的 `device_model` 就是一串数字
- **注册表只增不减**：`destroy()` 的清理逻辑被注释掉了（原注释：`# might cause conflict, disabled for now, it won"t be a problem`），所以每次 `Generate()` 都会让类级列表永久增长。长驻进程 / 批量循环要注意

## 三、Telethon 集成

`opentele.tl.TelegramClient` 是 Telethon `TelegramClient` 的子类：

```python
# tl/telethon.py
if isinstance(api, APIData) or (isinstance(api, type) and APIData.__subclasscheck__(api) and api != APIData):
    api_id = api.api_id
    api_hash = api.api_hash
    kwargs["device_model"] = api.pid
```

- 传 `api=<APIData 实例或类>` → OpenTele 接管 `api_id` / `api_hash` / 设备字段
- **不要再单独传 `api_id` / `api_hash`**，会被 `api` 覆盖
- 传 `api=None` 且未指定凭据 → 自动回落到 `API.TelegramDesktop`

因此**创建客户端后即可调用全部 Telethon 方法**：

```python
client = TelegramClient(session, api=api)
await client.connect()
await client.is_user_authorized()
me = await client.get_me()
await client(functions.help.GetAppConfigRequest(hash=0))   # 自定义请求同样可用
await client.disconnect()
```

`api` 默认值在签名里就是 `API.TelegramDesktop`，**不传 `api` 时会悄悄用 Desktop 模板**——如果会话原本不是 Desktop 授权的，这就是踩雷点。永远显式传。

## 四、模板全表

| 类 | api_id | api_hash | device_model | system_version | app_version | lang_pack |
|---|---|---|---|---|---|---|
| `TelegramDesktop` | `2040` | `b18441a1ff607e10a989891a5462e627` | `Desktop` | `Windows 10` | `3.4.3 x64` | `tdesktop` |
| `TelegramAndroid` | `6` | `eb06d4abfb49dc3eeb1aeb98ae0f581e` | `Samsung SM-G998B` | `SDK 31` | `8.4.1 (2522)` | `android` |
| `TelegramAndroidX` | `21724` | `3e0cb5efcd52300aec5994fdfc5bdc16` | `Samsung SM-G998B` | `SDK 31` | `8.4.1 (2522)` | `android` |
| `TelegramIOS` | `10840` | `33c45224029d59cb3ad0c16134215aeb` | `iPhone 13 Pro Max` | `14.8.1` | `8.4` | `ios` |
| `TelegramMacOS` | `2834` | `68875f756c9b437a8b916ca3de215815` | `MacBook Pro` | `macOS 12.0.1` | `8.4` | `macos` |
| `TelegramWeb_Z` | `2496` | `8da85b0d5bfe62527e5b244c209159c3` | Mozilla UA 串 | `Windows` | `1.28.3 Z` | `""` |
| `TelegramWeb_K` | `2496` | `8da85b0d5bfe62527e5b244c209159c3` | Mozilla UA 串 | `Win32` | `1.0.1 K` | `macos` |
| `Webogram` | `2496` | `8da85b0d5bfe62527e5b244c209159c3` | Mozilla UA 串 | `Win32` | `0.7.0` | `""` |

`lang_code` 与 `system_lang_code` 各模板均为 `en` / `en-US`。

后三个浏览器模板无法 `Generate()`。

## 五、依赖与兼容风险

`requirements.txt` 内容（三行，均未锁版本）：

```
pyqt5
telethon
tgcrypto
```

- `telethon` 未锁 → 当前 Telethon 已到 **1.45.0（2026-09-10）**，而 OpenTele 停更于 2024-07，两者相差约两年
- `pyqt5` 是 tdata 相关模块的依赖，纯用 API 模板也会被装上

**建议**：在自己的项目里显式锁死 `opentele==1.15.1` 与一个实测可用的 `telethon==x.y.z`，升级前先跑连接测试。

若 OpenTele 因 Telethon 升级而失效：`src/api.py` 中的模板本质只是**一组类属性常量**（见上表），可以直接把需要的模板常量内联进自己的代码，摆脱这个不再维护的依赖。

## 六、`Generate()` 与 `unique_id` 的调用样例

```python
from opentele.api import API

# 推荐：显式 system + 稳定 unique_id
api = API.TelegramDesktop.Generate(system="windows", unique_id="my.session")
print(api.device_model, "|", api.system_version, "|", api.app_version)
# 每次运行输出完全一致

# 反例：不传 unique_id，每次都是新随机值
api = API.TelegramDesktop.Generate(system="windows")
# 下一次运行结果不同
```

库自身的文档也用同样写法（同一条 `unique_id` 永远得到同一份数据）：

```python
oldAPI = API.TelegramDesktop.Generate(system="windows", unique_id="old.session")
oldclient = TelegramClient("old.session", api=oldAPI)
```

官方还建议 `unique_id` 用**会话文件名或 `user_id`**——两者都天然满足"对该账号唯一且稳定"。

## 七、实测结果

环境：`opentele 1.15.1` + `telethon 1.45.0`（本机实测，两者共存，设备生成本身工作正常）。

### 7.1 `unique_id` 的确定性

```
同 unique_id='demo.session' 连续三次 →  0KV3RP | Windows 8
                                        0KV3RP | Windows 8
                                        0KV3RP | Windows 8

无 unique_id 连续三次             →  VPCF1290X | Windows 7
                                     MS-7A62   | Windows 10
                                     0WCNK6    | Windows 7
```

完全符合源码推断。

### 7.2 `app_version` / `pid`

```
Generate() 后：
  app_version = '3.4.3 x64'      ← 模板默认值（Generate 不随机这个字段）
  lang_pack   = 'tdesktop'
  pid         = 10700917222483192638
再次 Generate()：
  pid         = 2232818233756981845     ← 每实例都不同
  a == b ?    = False                    ← __eq__ 按 pid 比较
```

再次印证：**`pid` 随机且不进记录**。

### 7.3 各平台的生成样例

| 调用 | 生成结果样例 |
|---|---|
| `system="windows"` | `HP Pavilion Sleekbook 14` / `Windows 8.1` |
| `system="macos"` | `iMac` / `macOS 10.12.6` |
| `system="linux"` | `USOPP_BH` / `Linux XFCE X11 glibc 2.32` |
| 不传 `system` | `MacBook Pro` / `macOS 10.15.7`、`D900T` / `Linux GNOME Wayland glibc 2.32` … |

三个分支都能正常调用。`LinuxDevice.deviceList` / `macOSDevice.deviceList` 初始为空，由 `__gen__()` 懒加载填充，**不会**因空列表而 `ZeroDivisionError`。

注意 `linux` 的 `device_model` 是主板型号（`USOPP_BH`），**不含 "linux" 子串**；系统类型只出现在 `system_version` 里。
