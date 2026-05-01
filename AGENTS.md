# AGENTS.md

Этот файл содержит правила репозитория для coding-агентов.

## Обзор проекта

- Проект: `mac-mic-widget` (`Mac Mic Widget`)
- Тип: утилита микрофона в строке меню macOS
- Язык: Swift
- UI-стек: AppKit (`NSStatusItem` + `NSPopover`) + SwiftUI-контент поповера
- Инструмент сборки/тестов: Swift Package Manager

## Источники истины

Перед внесением изменений в функциональность обязательно прочитать:

1. `docs/PRODUCT_REQUIREMENTS.md` - реализованное поведение продукта и ограничения.
2. `Sources/MacMicWidget/MacMicWidgetApp.swift` - модель взаимодействия со status item.
3. `Sources/MacMicWidget/Services/MicrophoneService.swift` - логика чтения/записи уровня и toggle.
4. `Sources/MacMicWidget/MenuBarView.swift` - поведение UI поповера.

## Контракт взаимодействия (не ломать)

- Левый клик по status item открывает/закрывает popover.
- Правый клик (и `ctrl+left click`) переключает mute/unmute микрофона.
- Правый клик не должен открывать popover.

## Аудио-контракт (не ломать)

- `toggleMute()` должен сохранять последний ненулевой уровень.
- Восстановление не должно опускаться ниже `5%` (`0.05` в нормализованной шкале).
- Предпочитать чтение/запись системного input volume через AppleScript-путь.
- CoreAudio fallback должен оставаться рабочим.

## UI-контракт (не ломать)

- В строке меню отображается единая template-иконка с visual-уровнем (variable SF Symbol `mic.and.signal.meter.fill` / `mic.slash.and.signal.meter.fill` при mute, при необходимости fallback на `mic.and.signal.meter.fill`), чтобы ширина status item оставалась стабильной; число процентов — в popover и tooltip.
- В muted-состоянии состояние должно определяться формой иконки (`mic.slash.and.signal.meter.fill`) и `variableValue = 0`; не добавлять текст в status item.
- Кнопка mute/unmute в popover должна сохранять стабильную ширину между состояниями.
- Слайдер `Input level` в popover должен занимать всю доступную ширину контента и оставаться единым источником отображения/изменения уровня.

## Чеклист проверки после изменений

1. Запустить тесты: `make test`
2. Если поведение менялось, проверить вручную:
   - левый клик: открытие/закрытие popover
   - правый клик: mute/unmute без открытия popover
   - обновление visual-уровня иконки в строке меню (`variableValue`) после изменения input volume в системе
3. Проверить отсутствие заметных «скачков» ширины:
   - status item в строке меню (иконка)
   - кнопка mute/unmute в popover

## Команды разработки

- Запуск приложения: `make run`
- Watch-режим: `make dev`
- Тесты: `make test`
- Сборка: `make build`

## Рекомендации по правкам

- Делать изменения минимальными и локальными.
- Не удалять существующие fallback-пути без подтвержденной лучшей замены.
- Сохранять безопасность `@MainActor` вокруг UI и обновления состояния микрофона.
