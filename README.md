# Tomilo Lib — читалка манги для Android

Мобильное приложение на Flutter для чтения манги, манхвы и маньхуа с сайта tomilo-lib.ru.

## Функционал

- 📚 **Каталог** — сетка тайтлов с обложками, рейтингом, просмотрами
- 🔍 **Поиск** — по названию
- 🎛️ **Фильтры** — тип, статус, сортировка
- 📖 **Ридер** — вертикальный (лента) и горизонтальный (постраничный) режимы
- 🔖 **Закладки** — сохранение любимых тайтлов
- 🕐 **История чтения** — возврат к последней прочитанной главе
- 💾 **Прогресс** — запоминает страницу в каждой главе
- 🔒 **Платные главы** — отображаются как заблокированные

## Установка и сборка

### Требования
- Flutter 3.19+ (`flutter --version`)
- Android Studio или VS Code с плагином Flutter
- Android SDK (API 21+)

### Шаги

```bash
# 1. Распакуй архив
unzip tomilolib_app.zip
cd tomilolib_app

# 2. Установи зависимости
flutter pub get

# 3. Запусти на подключённом телефоне (режим разработчика включён)
flutter run

# 4. Или собери APK
flutter build apk --release

# APK будет тут:
# build/app/outputs/flutter-apk/app-release.apk
```

### Быстрый запуск в Android Studio
1. File → Open → выбери папку `tomilolib_app`
2. Подожди пока загрузятся зависимости (Pub get)
3. Выбери устройство вверху
4. Нажми Run ▶️

## Структура проекта

```
lib/
  main.dart                 — точка входа
  models/
    title_model.dart        — модель тайтла
    chapter_model.dart      — модель главы
  services/
    api_service.dart        — запросы к tomilo-lib.ru API
    storage_service.dart    — закладки, история, прогресс
  screens/
    catalog_screen.dart     — главный экран (каталог + поиск + фильтры)
    title_screen.dart       — страница тайтла
    reader_screen.dart      — ридер манги
    bookmarks_screen.dart   — закладки
    history_screen.dart     — история чтения
```

## API tomilo-lib.ru

```
GET /api/titles?sortBy=weekViews&sortOrder=desc&page=1&limit=24
GET /api/titles/slug/{slug}
GET /api/titles/{id}
GET /api/chapters/title/{titleId}?page=1&limit=10000&sortOrder=asc

Картинки:
https://s3.regru.cloud/tomilolib/titles/{titleId}/chapters/{chapterId}/cover_{N}.jpeg
```

## Возможные улучшения

- Авторизация через аккаунт tomilo-lib
- Скачивание глав оффлайн
- Уведомления о новых главах
- Тёмная/светлая тема на выбор
- Настройки ридера (масштаб, яркость)
"# toolmanga" 
