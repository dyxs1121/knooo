# 卡管家 · iOS App（可出 IPA）

信用卡账单 / 活动 / 提醒管理 App，SwiftUI 编写，**iOS 15.0+**（TrollStore 友好，arm64）。

```
CardKeeper/
├── CardKeeper.xcodeproj/          # Xcode 工程（已配好 target / scheme / 图标）
├── CardKeeper/                    # 全部源码
│   ├── CardKeeperApp.swift        # 入口 + TabView
│   ├── Models.swift               # 数据模型 + Store + 演示数据
│   ├── Theme.swift                # 配色 / 格式化 / 通用组件 / 卡面
│   ├── HomeView.swift             # 首页：总览 + 卡片横滑 + 提醒
│   ├── BillsView.swift            # 账单：筛选 + 汇总 + 按日明细
│   ├── ActivitiesView.swift       # 活动：打卡 / 记一笔 / 详情 / 添加表单
│   ├── StatsView.swift            # 统计：环形图 / 趋势 / 额度 / 排行
│   ├── ProfileView.swift          # 我的：提醒开关 / 卡片编辑
│   ├── Notifier.swift             # 本地通知（还款 + 活动提醒）
│   └── Assets.xcassets            # App 图标 + 强调色
└── .github/workflows/build-ipa.yml # 云端自动出 IPA
```

## ⚠️ 之前 Actions 跑失败的原因（2026-11 修正）

GitHub 已于 **2026 年 11 月 2 日下线 `macos-14` 运行器**，旧版 workflow 里的
`runs-on: macos-14` 会让任务在启动阶段直接报错，一次都跑不起来（与代码无关）。

现已改为 `runs-on: macos-15`（默认 Xcode 16.4），并新增：

- **自动定位工程**：即使上传时多套了一层 `CardKeeper/` 文件夹也能找到 `.xcodeproj`；
- **工程预检**：`xcodebuild -list` 先确认工程可被 Xcode 读取；
- **失败摘要**：编译失败时自动 `grep error:` 并打印日志末尾 120 行；
- **日志留存**：每次运行都上传 `build-log`，便于排查。

> 如果将来 `macos-15` 也被下线，把 `runs-on` 改成 `macos-latest` 即可。

## 路径 C：Codemagic 构建（不用 GitHub Actions）

仓库里已带 `codemagic.yaml`（构建未签名 IPA，配置与 Actions 版相同）：

1. 把 **`codemagic.yaml` 放到仓库根目录**（不是 `CardKeeper` 文件夹里面，是最外层，
   和 `.github` 同级——Codemagic 只认根目录的这一个文件名）；
2. Codemagic → Application settings → 右上角 **Check for configuration files**；
3. 顶部选 workflow **卡管家 · 未签名 IPA**（`cardkeeper-ipa`）→ **Start build**；
4. 构建约 5 分钟，完成后进 Builds → 这次构建 → **Artifacts** 下载 `CardKeeper-unsigned.ipa`；
5. 免费套餐每月 500 分钟，无需 Apple 开发者账号，无需签名配置。

## 路径 0（你的情况）：TrollStore 直接装

TrollStore 是**免签名**安装器，但它仍然需要一个 **IPA 文件**——只是不需要证书。
所以流程是「构建出未签名 IPA → 传到手机 → TrollStore 安装」，共 3 步：

### 第 1 步：生成 IPA（约 3 分钟，一次性）

1. 登录 [github.com](https://github.com)，新建一个**公开仓库**（Public），名字随意，如 `cardkeeper`；
2. 把本文件夹内所有内容上传到仓库根目录——**包括隐藏的 `.github` 文件夹**
   （网页上传：全选 `CardKeeper` 里的文件拖进去，GitHub 会保留目录结构）；
3. 进仓库 **Actions** 页签 → 左侧 **Build IPA** → 右侧 **Run workflow** → 绿色按钮确认；
4. 等 2–3 分钟变绿，打开 `https://github.com/你的用户名/cardkeeper/releases`
   就能直接下载 `CardKeeper-unsigned.ipa`（**手机浏览器也能下，不用登录**）。

> 产物是**未签名 IPA**，正好是 TrollStore 需要的。每次改代码重新跑一次即可。

### 第 2 步：把 IPA 放到 iPhone

任选一种：

- 电脑 AirDrop 到 iPhone；
- 微信「文件传输助手」发给自己 → 点开 → 右上角 → **存储到「文件」**；
- iCloud Drive / 网盘下载到「文件」App。

> 如果你下载到的是 `.zip`（Actions 的 Artifacts 会打包成 zip），在「文件」App 里
> 长按 → **解压**，得到 `CardKeeper-unsigned.ipa`。

### 第 3 步：TrollStore 安装

**方式 A（最快）**

1. 打开「文件」App，找到 `CardKeeper-unsigned.ipa`；
2. 长按文件 → **共享** → 在应用列表里选 **TrollStore**；
3. TrollStore 弹出安装页 → 点 **Install**；
4. 回桌面，「卡管家」图标已就位。

**方式 B**

1. 打开 TrollStore → 右上角 **+**；
2. 在文件选择器里选中那个 IPA；
3. 点 **Install**。

### 装完须知

| 项目 | 说明 |
|---|---|
| 签名有效期 | TrollStore 用 ldid 伪签名，**不会掉签**，重启后仍可打开 |
| 系统要求 | 工程最低版本已降到 **iOS 15.0**，覆盖 TrollStore 主流系统区间（14.x 需自行再降，见文末） |
| Bundle ID | 已设为 `com.ck.cardkeeper`，避免冲突；同 ID 重装为覆盖升级，**数据保留** |
| 通知权限 | 首次启动会弹窗；若没弹，去「设置 → 通知 → 卡管家」手动开启（本地通知不依赖证书） |
| 刷新注册 | 若某次重启后图标变白打不开，打开 TrollStore → 下拉/Refresh App Registrations 一次即可 |
| 卸载 | 桌面长按删除，或在 TrollStore 中左滑删除 |

---

## 为什么这里不能直接给你 IPA

IPA 内部是链接了 Apple iOS SDK 的 arm64 二进制，**必须用 macOS + Xcode 编译**。
本环境是 Linux，没有 iOS SDK，无法产出真正可安装的 IPA。

因此提供两条**都能拿到 IPA** 的路径，选一条即可：

---

## 路径 A（推荐）：GitHub 云端构建，不需要 Mac

1. 注册 / 登录 [github.com](https://github.com)，新建一个**公开仓库**（如 `cardkeeper`）；
2. 把 `CardKeeper` 文件夹里的所有内容（含隐藏的 `.github`）上传到仓库根目录；
   - 网页端拖拽上传即可，注意把 `.github/workflows/build-ipa.yml` 传上去；
3. 打开仓库的 **Actions** 页签 → 左侧 **Build IPA** → 右上 **Run workflow**；
4. 构建约 2–3 分钟，完成后在该次运行页面底部的 **Artifacts** 下载 `CardKeeper-unsigned-ipa`，
   解压得到 `CardKeeper-unsigned.ipa`（未签名）；
5. 签名安装（见下方「签名与安装」）。

> 每次改动代码 push 上去都会自动重新构建。

## 路径 B：有 Mac / 借一台 Mac

1. 把 `CardKeeper` 文件夹拷到 Mac，双击 `CardKeeper.xcodeproj` 打开；
2. 选中项目 → **Signing & Capabilities** → 勾选 Automatically manage signing，选择你的 Team
   （没有付费账号时，用免费 Apple ID 在 Xcode → Settings → Accounts 登录即可）；
3. iPhone 用数据线连接，信任电脑，顶部选择你的手机 → **Run（⌘R）** 直接安装调试；
4. 或 **Product → Archive → Distribute App → Custom / Development** 导出已签名 IPA。

---

## 签名与安装（针对未签名 IPA）

| 工具 | 平台 | 说明 |
|---|---|---|
| **Sideloadly** | Windows / Mac | 最简单。IPA 拖进去 + 填自己的 Apple ID → 签名 → 安装。免费账号 7 天有效期，最多 3 台设备 |
| **AltStore / SideStore** | iOS | 手机端自签 + 自动续签 |
| **TrollStore** | iOS 14.0–16.6.1（部分版本） | 永久签名，可直接装未签名 IPA |
| **付费开发者账号** | — | 签名后 1 年有效 |

如果 Sideloadly 报 bundle id 冲突，在它的选项里把 Bundle ID 改成
`com.你的名字.cardkeeper` 再签即可。

## 功能对照

| 功能 | 实现位置 |
|---|---|
| 账单日 / 还款日管理（增删改） | ProfileView（卡片管理）+ Models |
| 还款倒计时 / 本期应还 | Models 计算属性 + HomeView 卡面 |
| 账单明细与总额 | BillsView（按卡筛选 + 按日分组） |
| 可视化 | StatsView（自绘环形图 / 柱状图，无第三方依赖） |
| 活动自定义（次数 / 金额 / 单次） | ActivitiesView + ActivityEditorView |
| 打卡确认完成 | Store.toggleStep / checkNextStep / setDone |
| 消息提醒 | Notifier：还款提前 N 天每月循环提醒 + 活动按周期提醒（UserNotifications 本地通知，数据不出设备） |
| 数据持久化 | UserDefaults + Codable，首次启动自动载入演示数据，「我的 → 重置演示数据」可还原 |

## 二次开发提示

- 改 App 名字：`project.pbxproj` 里 `INFOPLIST_KEY_CFBundleDisplayName`；
- 改 Bundle ID：`PRODUCT_BUNDLE_IDENTIFIER`（签名前改成自己的）；
- 最低系统：iOS 15.0（在 target 的 `IPHONEOS_DEPLOYMENT_TARGET`）；如需降级到 iOS 14，
  要替换 iOS 15 专属 API（`Section("标题")`、`alert(_:isPresented:)`、`TextField(value:format:)`、
  `@Environment(\.dismiss)` 等），工作量不大但需逐个改。
- 通知需要授权：首次启动会弹出，也可在系统设置里手动开启。
