# Dopamine Rose — 04 灰粉 UI

作者：Ning&opa334；基于 w2599/Dopamine 分支 3.x_modify_，基线 6522285754fd9c4574e9afc352dc31fe548567fc。

此仓库保存整个 App 的灰粉居中、酒红强调色 UI 源码，包括首页、设置与二级页、关于与许可、更新下载、日志错误、包管理器及弹窗。旧主题保留，未设置主题或旧默认绿色会一次迁移为 dusty-rose。越狱业务源与上游保持。

## 构建

在 GitHub Actions 选择 **Build Dopamine Rose → Run workflow → main**。只支持手动触发；提交源码不会自动构建或发布 Release。macos-latest 构建完整应用，产物为 `Dopamine-Rose_<版本>_<提交>.tipa`，可通过 TrollStore 安装。它是 App 安装包，非按 rootless/RootHide 拆分的 deb 插件。

构建保留上游实际版本 3.0.13、bundle ID com.zqbb.Dopamine 和原始签名权限。流程先核对 reviewed-source.json 中全部源文件及四个子模块的固定提交，再执行上游必要构建准备、编译和安装包校验。下载 bootstrap、安装工具链需要网络。原构建流程对来源账号和 bundle ID 的替换保留；没有在源代码中写入令牌。

UI 修改已通过 clang-19/iPhoneOS16.5 的 26 文件 × arm64/arm64e 52 项语法检查；这不等于 Xcode 链接或真机运行通过。CI 结果以该提交的实际运行记录为准。

上游许可与原作者信息保留在仓库原有 LICENSE 文件中。
