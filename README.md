# TiebaAdsBlocker

百度贴吧 iOS 去广告 dylib 插件。注入 `com.baidu.tieba` 进程，屏蔽开屏广告、信息流广告、帖子内广告及横幅广告。

## 原理

采用多层防御策略：

| 层级 | 方式 | 说明 |
|------|------|------|
| 网络层 | URL 拦截 | 通过 hook `NSMutableRequest.setURL:` 将请求重定向到已知广告域名 |
| 数据层 | Cell 过滤 | 检测 TableView/CollectionView Cell 的广告特征并隐藏 |
| 视图层 | 子树扫描 | 递归扫描 UIView 层次，根据类名、标识符、文本标记识别广告 |
| VC 层 | 广告页面跳过 | 识别开屏/广告 ViewController 并自动 `dismiss` |
| 定时清理 | 周期扫描 | 每 2s 对全部 UIWindow 做一次广告清理，防止延迟加载的广告漏网 |

## 环境要求

- iOS 14.0+
- 越狱设备（arm64 / arm64e）
- [Theos](https://github.com/theos/theos) 构建环境

## 构建

```bash
# 确保已安装 Theos
export THEOS=/path/to/theos

# 编译
make clean package

# 如果指定部署到设备
make clean package install

# 生成的 .deb 在 packages/ 目录下
```

## 安装

**Cydia / Sileo / Zebra：**

直接用越狱包管理器打开生成的 `.deb` 文件安装，或者在设备终端：

```bash
dpkg -i com.codex.tieba.adsblocker_1.0.0_iphoneos-arm.deb
killall -9 com.baidu.tieba
```

**手动注入（无越狱环境参考）：**

1. 将 `TiebaAdsBlocker.dylib` 拷贝到越狱设备
2. 使用 `insert_dylib` 将 dylib 注入到贴吧 Mach-O 二进制
3. resign + 安装

## 扩展广告域名

编辑 `Tweak.xm` 中的 `adDomains()` 函数，添加新发现的广告域名后重新编译即可。

## 注意事项

- 部分类名和标识符依赖逆向分析结果，贴吧版本更新后可能需要适配
- 本插件仅用于学习和研究目的
- 请遵守百度贴吧用户协议及相关法律法规
