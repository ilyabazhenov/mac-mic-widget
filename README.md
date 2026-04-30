# mac-mic-widget

`mac-mic-widget` (`Mac Mic Widget`) — лёгкое приложение для строки меню macOS, которое показывает текущий уровень входного микрофона и позволяет быстро переключать mute/unmute.

## Поведение

- В строке меню — монохромная иконка с visual-индикатором уровня (SF Symbol); точный процент и progress bar — в popover (и процент в tooltip иконки).
- Клик по иконке в строке меню переключает уровень микрофона между:
  - `0%` (микрофон выключен)
  - последним ненулевым значением (восстанавливается при следующем переключении)
- Если предыдущий ненулевой уровень неизвестен, используется fallback-значение `5%`.

## Требования

- macOS 14+
- Xcode 15+ или Swift 6.3 toolchain
- Аудиоустройство, у которого доступна запись в `kAudioDevicePropertyVolumeScalar` для input scope

## Install / Download

- Последний релиз: [GitHub Releases](https://github.com/ilyabazhenov/mac-mic-widget/releases/latest)
- Для быстрой сборки release-артефакта локально:

```bash
scripts/release/package_release.sh
```

Скрипт берёт версию из файла `VERSION`. При необходимости можно передать явный override:

```bash
scripts/release/package_release.sh v0.1.3
```

На первом этапе релизы распространяются как unsigned build. macOS может показать предупреждение Gatekeeper:

1. Скачай и распакуй `MacMicWidget-<version>-macos-arm64-unsigned.zip`.
2. Перетащи `MacMicWidget.app` в `Applications`.
3. Открой `System Settings -> Privacy & Security`, найди блок про blocked app и нажми `Open Anyway`.
4. Подтверди запуск в системном диалоге.

## Запуск

1. Открой пакет в Xcode:
   - `open Package.swift`
2. Выбери схему `MacMicWidget` и запусти.
3. Иконка микрофона появится в строке меню.

Или запуск из терминала:

```bash
make run
```

Автоперезапуск при изменении файлов:

```bash
brew install watchexec
make dev
```

## Тесты

Запуск:

```bash
make test
```

## Примечания и ограничения

- Некоторые USB/Bluetooth-гарнитуры отдают input gain в нестандартном виде и могут не поддерживать запись через CoreAudio scalar property.
- Приложение не захватывает аудио с микрофона: оно только читает/изменяет входной gain у устройства, выбранного системой как default input.
