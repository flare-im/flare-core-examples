/// 与 [flare-core-vue-im-ui] `FlareLocale` 对齐的示例应用语言。
enum FlareLocale {
  zhCn('zh-CN'),
  enUs('en-US');

  const FlareLocale(this.code);

  final String code;

  static FlareLocale fromCode(String? code) {
    final normalized = (code ?? '').trim().toLowerCase();
    if (normalized.startsWith('en')) return FlareLocale.enUs;
    return FlareLocale.zhCn;
  }
}
