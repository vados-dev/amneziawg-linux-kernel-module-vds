03 — Задачи
Исторически извлечено из AGENTS.md; актуальный источник — этот файл.

Статусы: `[ ]` не начато · `[-]` реализовано, ожидает проверки · `[x]` выполнено и проверено · `[!]` частично, есть незакрытые требования.

Закрытые пункты переносятся в `.agents/logs/YYYYMMDDHHMM-reports.md`, выявленные проблемы — в `05-issues.md`.

## Активные задачи

### Архитектору — 13.11.2026 14:31 MSK

- [x] Проверить `06-debug.md` и предложить исправление ошибок. Записать план в `04-plans.md`
  и ждать подтверждения либо корректировок от владельца проекта.
  - [x] Сверка `03-tasks.md` с фактическим состоянием репозитория —
    отчёт `.agents/logs/202611131431-reports.md`.
  - [x] План исправлений по `06-debug.md` — `04-plans.md`, Phase C.
  - [x] Подтверждение владельца получено, план передан в Code.

### Workflows и скрипты — 13.11.2026

Основание: постановка владельца (пункты 1–5 ниже) и результаты отладки в `06-debug.md`.
Код реализован 13.11.2026 14:52 MSK; проверка запуском — за владельцем (правило 7).
Отчёт о реализации — `.agents/logs/202611131452-reports.md`.

1. [-] Переделать `scripts/setup.sh` под задачи временного образа для `.github/workflows/merge.yml`.
   - [x] Скрипт работает только с флагами запуска; без флагов выводит справку и выходит.
   - [x] Диспетчер действий внизу оформлен через `case`, функции возвращают код, `exit` —
     только в ветках `case`.
   - [x] Аргумент версии ядра `-k/--kernel` и локальная сборка `-l/--local`.
   - [x] Перенесены и упорядочены `check_os`, `latest_installed_kernel`, `install_deps`;
     проверка ОС ограничена RHEL-семейством 9–10.
   - [x] Пустой `-k` означает установку последнего доступного ядра, а не `uname -r`.
   - [x] Образ обновляется до указанной версии ядра до сборки; сборка идёт по
     `kernel-devel` целевой версии, а не по работающему ядру контейнера.
   - [x] Добавлен неинтерактивный режим `-y/--yes`; неявный `dnf update` из `install_deps`
     убран.

2. [-] Полностью переписать `.github/workflows/check-upstream.yml`.
   - [x] Сравнение последнего тега upstream с `internal/config/version`.
   - [x] Поддержка `manual_tag` и repo variable `DEFAULT_TAG`; приоритет
     `manual_tag` → `DEFAULT_TAG` → последний тег upstream.
   - [x] Создание issue с checklist миграции VDS; уведомление в telegram при сбое.
   - [x] Нормализация тега: `v`-префикс и «голый» тег сравниваются одинаково.
   - [x] В тексте issue используется `upstream_ref`; ручной запуск `stable.yml` удалён.
   - [x] Добавлены inputs `NOTIFY_ON_UPDATE`/`NOTIFY_ON_RESULT` и env `TG_TOKEN`/`TG_CHAT_ID` в шагах из Repository secrets.
   - [x] `merge.yml` запускается по флагу `run_merge` и только при найденном новом теге.
   - [x] Автоматические триггеры закомментированы; `workflow_dispatch` оставлен для
     ручного запуска владельцем.

3. [x] Переделать `src/Makefile` и `internal/vds/src/Makefile`.
   - [x] Единственный источник версии — `src/version.h` (`3.1.20260812-vds`).
   - [x] Вычисление версии из даты git-коммита убрано.
   - [x] `print-version` и `dkms-install` используют версию из `version.h`.
   - [x] `internal/config/version` — `3.1.20260812`; `internal/config/current` — `3.1.20260812-vds`.

4. [-] Написать `.github/workflows/merge.yml` с учётом целей, планов и задач проекта.
   - [x] Каркас файла, job `merge`, обновление зависимостей через `scripts/setup.sh -d -y`.
   - [x] Копирование upstream в отдельное дерево и overlay `internal/vds/src`.
   - [x] `inputs` убраны из `env`; статические значения по умолчанию:
     `UPSTREAM_REF=master`, `KERNEL_VERSION` пусто, `VDS_BRANCH=master`.
   - [x] `upstream_ref` и `kernel_version` не обязательны; пустая версия ядра = последняя.
   - [x] `dry_run` по умолчанию `true`; push выполняется только при явном `dry_run=false`.
   - [x] Автоматический запуск убран; входы `workflow_call` и `workflow_dispatch`.
   - [x] `stable.yml` вызывается через `workflow_call`, ожидание — через зависимость job.
   - [x] Правило 11: `internal/vds/src` синхронизируется, корневые файлы upstream
     сравниваются с предыдущей версией, при изменениях — уведомление.
   - [x] Версия берётся из тега или из `src/version.h` upstream, а не из имени ветки.
   - [x] Токен не сохраняется в `.git/config`.
   - [x] Runner закреплён: `ubuntu-24.04`.
   - [x] Добавлены inputs `NOTIFY_ON_UPDATE`/`NOTIFY_ON_RESULT` и env `TG_TOKEN`/`TG_CHAT_ID` в шагах из Repository secrets.

5. [-] Написать `.github/workflows/stable.yml` с учётом целей, планов и задач проекта.
   - [x] Тег вида `v$(cat internal/config/current)`, например `v3.1.20260812-vds`.
   - [x] Архивы в Assets, обновление ветки stable.
   - [x] Единственный вход — `workflow_call`; `workflow_dispatch` и `workflow_run` убраны.
   - [x] Проверка успешного завершения `merge.yml` — через зависимость job.
   - [x] Ветка `stable` создаётся явно из исходной ветки `master`.
   - [x] Runner закреплён, добавлены inputs `NOTIFY_ON_UPDATE`/`NOTIFY_ON_RESULT` и env `TG_TOKEN`/`TG_CHAT_ID` в шагах.

6. [-] Telegram-уведомления: единый `notify_mode` (`choice` в `workflow_dispatch`,
   `string` в `workflow_call`) со значениями `none|inherit|changes|always`, default `none`;
   `auto_merge` вместо инвертированного `NOTIFY_ON_UPDATE`; kill-switch `vars.TELEGRAM_NOTIFY`;
   один шаг уведомления на прогон. Repository secrets `TELEGRAM_BOT_TOKEN`/`TELEGRAM_CHAT_ID`
   → env `TG_TOKEN`/`TG_CHAT_ID` в шагах. Ожидает проверки запуском.

### Workflows: CI-образ для merge.yml — 13.11.2026 23:50 MSK

Основание: постановка владельца — использовать для `merge.yml` готовый образ
`ghcr.io/vados-dev/amneziawg-linux-kernel-module-vds/centos-10:lts`.
План — `04-plans.md`, Phase E. Ожидает подтверждения владельцем.

1. [ ] Перевести job `merge` на CI-образ GHCR, добавить `packages: read` и credentials.
2. [ ] Заменить `Install bootstrap tools` на проверку инструментов образа.
3. [ ] Добавить в `scripts/setup.sh` fallback с включением EPEL/CRB при установке `dkms`.
4. [ ] Проверка: dry-run `merge.yml` владельцем (правило 7).

## Отработано

Перенесено в `.agents/logs/202611131431-reports.md`, раздел 1.
Кратко: версия и Makefile (пункт 3) закрыты полностью; в пунктах 1, 2, 4, 5 закрыта
первичная реализация, остаточные требования выполнены 13.11.2026 и ожидают проверки
запуском workflows владельцем.
