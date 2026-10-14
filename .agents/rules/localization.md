# Localization Rule for FlipIt

Whenever adding, modifying, or refactoring user-facing text (buttons, labels, alerts, sheets, navigation titles, section headers, confirmation dialogs, accessibility labels):
1. **Never leave raw strings unlocalized**: All user-visible strings must be sourced from the dedicated localization files.
2. **Dual-language synchronization**: Every new string must immediately be added to both:
   - `FlipIt/en.lproj/Localizable.strings`
   - `FlipIt/pl.lproj/Localizable.strings`
3. **Key and format specifier consistency**:
   - Keys must match identically between `en` and `pl`.
   - Format specifiers (`%@`, `%lld`, `%d`, `%.1f`) must match identically.
4. **SwiftUI localization semantics**:
   - Interpolated integers in `Text("\(count) cards")` map to `"%lld cards"`.
   - Passing `String` variables to `Text()` or `Label()` must use `LocalizedStringKey(variable)` or `String(format: NSLocalizedString("...", comment: ""), ...)`.
   - Dynamic ternary expressions in `.navigationTitle()` or `Text()` must be wrapped in `LocalizedStringKey(...)`.
