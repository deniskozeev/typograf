<p align="center">
  <img src="design/appicon-dark.png" width="128" alt="Типограф">
</p>

<h1 align="center">Типограф</h1>

<p align="center">
  Менюбар-приложение для macOS: выделите текст в любом приложении,
  нажмите хоткей — и текст типографирован прямо на месте.
  <br>
  <em>Free macOS menu bar app that typographs selected Russian/English text in place.</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-13%2B-black" alt="macOS 13+">
  <img src="https://img.shields.io/badge/цена-бесплатно-63C470" alt="Бесплатно">
  <img src="https://img.shields.io/badge/license-MIT-blue" alt="MIT">
</p>

---

Пишете `"Привет" - это тест(c) 1/2`, нажимаете **⌃⌥T** — получаете
`«Привет» — это тест© ½`. Кавычки-ёлочки, правильные тире, неразрывные
пробелы, символы © ® ™, дроби — всё по правилам типографики, русской
и английской.

## Возможности

- **Работает везде** — в любом приложении, где можно выделить текст:
  браузер, мессенджер, редактор, почта.
- **105 правил** типографики из библиотеки
  [typograf](https://github.com/typograf/typograf) — любое можно включить
  или выключить в настройках.
- **Дружит с редакторами**: в Ghost, Notion и других визуальных редакторах
  сохраняет списки и заголовки; в Bear, Obsidian и других
  markdown-редакторах не трогает разметку.
- **Не портит буфер обмена** — то, что вы копировали до этого,
  вернётся на место.
- **Нативное и лёгкое**: Swift + AppKit, без Electron, бинарник меньше
  мегабайта, в памяти почти не заметно.
- **Автообновления** — новые версии прилетают сами (Sparkle).
- Хоткей настраивается, иконку в менюбаре можно скрыть.

## Установка

1. Скачайте `Typograf-x.y.z.zip` из [последнего релиза](https://github.com/deniskozeev/typograf/releases/latest),
   распакуйте и перенесите **Typograf.app** в «Программы».
2. При первом запуске macOS предупредит о неизвестном разработчике —
   откройте Настройки → Конфиденциальность и безопасность → **«Всё равно
   открыть»**. Это плата за то, что приложение бесплатное: подпись
   Apple Developer стоит $99/год.
3. Выдайте разрешение «Универсальный доступ» (приложение попросит само) —
   без него нельзя читать выделенный текст и заменять его.
4. Выделите текст, нажмите **⌃⌥T**. Готово — на иконке в менюбаре
   мигнёт зелёная точка.

Приложение **полностью бесплатное**, без подписок, аналитики и рекламы.
Если оно вам пригодилось и хочется сказать спасибо —
[угостите автора кофе](https://pay.cloudtips.ru/p/2e5a46a4) ☕️

## Благодарности

- [typograf](https://github.com/typograf/typograf) © Денис Селезнёв и
  контрибьюторы, MIT — сердце этого приложения, все правила типографики
  оттуда.
- [Sparkle](https://sparkle-project.org) — автообновления.
- [Literata](https://github.com/googlefonts/literata) © TypeTogether, OFL —
  фирменная «T» в логотипе.

## Автор

[Денис Козеев](https://kozeev.ru) — разработка сайтов и веб-сервисов.
Нашли баг или есть идея — пишите на
[dakozeev@gmail.com](mailto:dakozeev@gmail.com) или в
[Issues](https://github.com/deniskozeev/typograf/issues).

---

## Для разработчиков

<details>
<summary>Сборка и релиз</summary>

### Сборка

```bash
git clone https://github.com/deniskozeev/typograf.git
cd typograf
./build.sh
open build/Typograf.app
```

Нужен только Xcode (Swift 5.9+). `build.sh` собирает Swift Package,
складывает `.app`-бандл, генерирует иконку и подписывает первым
сертификатом подписи кода из Keychain (или ad-hoc, если сертификата нет).

После пересборки macOS может попросить выдать разрешение Accessibility
заново, если подпись нестабильна.

### Как это работает

По хоткею приложение эмулирует ⌘C, прогоняет текст (plain + HTML)
через typograf в системном JavaScriptCore, кладёт результат в буфер,
эмулирует ⌘V и восстанавливает прежний буфер. Глобальный хоткей —
Carbon `RegisterEventHotKey`, для эмуляции клавиш нужен Accessibility.

### Релиз

```bash
./release.sh 1.1.0
```

Скрипт поднимет версию, соберёт подписанный zip и `releases/appcast.xml`
(EdDSA-подпись Sparkle, ключ в Keychain) и подскажет команды `git tag` +
`gh release create` для публикации.

</details>

## Лицензия

[MIT](LICENSE). Правила типографики — библиотека
[typograf](https://github.com/typograf/typograf) © Denis Seleznev, MIT.
