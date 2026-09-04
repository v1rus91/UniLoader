# ⬇ UniLoader — нативний завантажувач медіа для macOS (Swift / SwiftUI)

Універсальний завантажувач відео та аудіо з **YouTube, Instagram, TikTok, Facebook, X, Reddit, Twitch, SoundCloud**
та понад **1000 інших сайтів** (ядро — yt-dlp). Написано на Swift 6 і SwiftUI, у стилі macOS 26 з **Liquid Glass**.

> ⚠️ Проєкт створено виключно з ознайомлювальною метою. Завантажуйте лише той контент, на який маєте право.

## Що всередині

**Версія 2.1** додала: вибір точного формату та елементів плейлиста, музичні сервіси (Spotify, Apple Music, Shazam, Deezer,
Tidal, Amazon Music, Яндекс Музика — трек визначається за посиланням і шукається на YouTube, аудіо зберігається з тегами),
стеження за буфером обміну, іконку в рядку меню та швидку панель ⌘⇧D, сповіщення й лічильник у Dock, збереження черги між
запусками, лог кожного завдання, cookies.txt, фрагменти/SponsorBlock/розділи/ліміт швидкості/проксі/довільні аргументи,
щотижневе оновлення yt-dlp, drag-and-drop файлів з історії та Quick Look, URL-схему `uniloader://` з букмарклетом для
браузера, англійську локалізацію та вбудований самотест.

- **Liquid Glass** (`glassEffect`, `.glass`/`.glassProminent`) на macOS 26 і матеріали з блюром на macOS 14–15
- Вікно з `thinMaterial`-фоном, плаваюча скляна бічна панель, уніфікований тулбар із пошуком
- Аналіз посилання: назва, автор, тривалість, перегляди, лайки, дата, мініатюра
- Відео 360p–4K з мерджем у MP4, аудіо mp3 / m4a / opus / wav / flac, плейлисти, субтитри, обкладинка, метадані
- Черга з паралельними завантаженнями (1–4), живий прогрес зі швидкістю та ETA, скасування, повтор
- Історія з пошуком, відкриття у Finder, повторне використання посилання
- Шорткати: `⌘V` вставити й проаналізувати (працює з будь-якою розкладкою), `↩` аналіз, `⌘↩` завантажити, `⌘N`, `⌘L`, `⌘F`, `⌘1…5`, `⌘,`, `⌘/`
- Drag-and-drop посилань із браузера, онбординг, тости, cookies із браузера для приватного контенту
- Справжні логотипи сервісів: 42 монохромні SVG із [Simple Icons](https://simpleicons.org) (CC0), тоновані фірмовим кольором,
  плюс 10 favicon-ів для решти; темні логотипи автоматично світлішають у темній темі
- Вбудовані `yt-dlp` (універсальний бінарник) і статичний `ffmpeg` — нічого доставляти не потрібно; оновлення yt-dlp однією кнопкою

## Збірка

Потрібні лише **Command Line Tools** (Xcode не обовʼязковий), macOS 14+ для запуску.

```bash
git clone <repo> UniLoaderSwift && cd UniLoaderSwift
# статичний ffmpeg покладіть у Resources/bin/ffmpeg (наприклад, з https://evermeet.cx/ffmpeg/)
./packaging/build.sh        # скачає yt-dlp, збере dist/UniLoader.app і dist/UniLoader-2.0.0.dmg
open dist/UniLoader.app
```

Для розробки: `swift build && .build/debug/UniLoader` (без бандла інструменти беруться з Homebrew/PATH).

Перевірки: `.build/debug/UniLoader --self-test` (27 перевірок парсера, аргументів, сервісів; запускається і в `build.sh`),
`.build/debug/UniLoader --resolve <посилання>` показує, як музичне посилання перетворюється на треки.
У `Tests/` є ті самі перевірки для Swift Testing (`swift test` під Xcode; Command Line Tools не запускають тестовий раннер).

Бандл підписано ad-hoc. На іншому Mac під час першого запуску: правий клік → **Відкрити**,
або `xattr -dr com.apple.quarantine /Applications/UniLoader.app`.

## Структура

```
Sources/UniLoader/
├── UniLoaderApp.swift      # @main, меню та шорткати (Commands)
├── AppModel.swift          # стан UI, дії, монітор ⌘V поза текстовими полями
├── DownloadManager.swift   # черга, воркери, історія, тости, системні дії
├── YTDLP.swift             # пошук бінарників, метадані, запуск завантаження з парсингом прогресу
├── Prefs.swift             # налаштування (UserDefaults, @Observable)
├── Models.swift            # моделі, статуси, форматування
├── Services.swift          # каталог 60 сервісів і визначення за URL
├── MusicResolver.swift     # Spotify / Apple Music / Shazam / Deezer / OpenGraph → треки
├── HotKey.swift            # глобальний хоткей ⌘⇧D (Carbon)
├── SelfTest.swift          # вбудовані перевірки (--self-test)
└── Views/                  # ContentView, Download, Queue, History, Services, Settings, Components
packaging/                  # Info.plist, build.sh
Resources/                  # іконка .icns, icons/ (логотипи сервісів), bin/yt-dlp, bin/ffmpeg
```

## Ліцензія

MIT. Лише для ознайомлення.
