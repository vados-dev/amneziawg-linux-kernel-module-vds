# AGENTS.md: роли и ответственность

Форк: `amneziawg-linux-kernel-module-vds`  
Исходный репозиторий (апстрим): [amnezia-vpn/amneziawg-linux-kernel-module](https://github.com/amnezia-vpn/amneziawg-linux-kernel-module)  
Код правок находится в `internal/vds/`. Редактирование файлов апстрима (`src/`, `debian/`, `kernel-tree-scripts/`) возможно только внутри тестового образа (merge.yml) — правки накладываются автоматически при сборке.

## Автоматизированные агенты (GitHub Actions)

| Агент | Роль | Триггер | Результат |
|-------|------|---------|-----------|
| `check-upstream.yml` | Мониторинг апстрима, подготовка CI-образа | Расписание (`schedule`) или ручной запуск | Обновляет `:current` образ, определяет необходимость merge, формирует входные данные для `merge.yml`. |
| `merge.yml` | Сборка, тестирование, публикация в testing | Вызов из `check-upstream` или `workflow_dispatch` (по умолчанию `dry_run=true`; для реального пуша — `dry_run=false`) | Пушит в ветку `testing-${version}-vds`, отчитывается в Telegram. Не трогает `master`. |
| `promote.yml` | Стабилизация (перенос в master + тег) | Только `workflow_dispatch` (ручной запуск) | Fast-forward `master` до `testing-${version}-vds`, создаёт тег `v${version}-vds`, пушит тег. |

## Человеческий агент

- **Верификация**: после появления ветки `testing-${version}-vds` выкати её на тестовый стенд (VDS), проверь работу модуля под целевым ядром.
- **Решение о стабильности**: если версия прошла проверку, вручную запусти `promote.yml`, указав версию.
- **Реакция на конфликты**: если `promote.yml` падает с ошибкой «не является потомком master», разбери причину (ручные правки в `master`, расхождение истории) и реши, как действовать.

## Важные ограничения

- Стабильные теги (`v*-vds`) неизменяемы: повторный промоут той же версии вызовет ошибку.
- Прямой пуш в `master` из CI запрещён; все изменения проходят через `testing` и ручной промоут.
- Автоматического переноса из `testing` в `master` нет: это сознательное решение для контроля качества.

## Git-ремоуты

- `origin` — [amnezia-vpn/amneziawg-linux-kernel-module](https://github.com/amnezia-vpn/amneziawg-linux-kernel-module) (апстрим)
- `gh` — [vados-dev/amneziawg-linux-kernel-module-vds](https://github.com/vados-dev/amneziawg-linux-kernel-module-vds) (этот форк)

> ⚠️ Не воспринимайте этот файл как руководство по эксплуатации. Читайте `.agents/00-index.md`.  
> По умолчанию для сессии: `.agents/00-index.md`, далее по нему.  
> По умолчанию branch: `master`.
