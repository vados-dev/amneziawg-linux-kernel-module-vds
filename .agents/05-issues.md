05 — Проблемы агентов
Исторически извлечено из AGENTS.md; актуальный источник — этот файл.

### 13.11.2026 12:07 MSK
Аудит агентских файлов и сверка с репозиторием.

1. `check-upstream.yml` содержал артефакты другого проекта: `AGENTS.md rule 8`, `origin/main`, `isolated-lucx-files`,
   `LUCX-HOOK`, `go build ./internal/awg/... ./internal/lucx/...`, frontend typecheck. Endpoint
   `releases/tag/latest` был неверным, нужен `releases/latest`. Не было `manual_tag`, repo variable `DEFAULT_TAG`
   и telegram-уведомления при сбое. Файл признан чужим образцом и переработан.
2. `merge.yml` и `stable.yml` были заглушками из одной строки `name:`, хотя `AGENTS.md` и `01-purpose.md`
   описывают их как рабочий процесс. Созданы каркасы.
3. `scripts/setup.sh`: переменные `ADD_AWG`, `CHK_AWG`, `ADD_WG`, `DEL_AWG`, `DEL_WG` не были инициализированы;
   диспетчер внизу был построен на `if`, `exit` находился внутри функций; не было аргумента версии ядра
   и обновления образа до неё. Исправлено.
4. `scripts/install-amneziawg-kernel.sh`: неопределённый `cur_dir`, `local` вне функции,
   невалидный `export ccflags-y +=`, `TOOLS_URL` указывает на module-репозиторий,
   `confirm` вызывается с двумя аргументами, дублируются переменные.
5. Версия приведена к единому виду: `src/version.h` и `internal/config/current` — `3.1.20260812-vds`,
   `internal/config/version` — `3.1.20260812`; `src/Makefile` читает версию из `version.h`.
6. Правило 8 (`README.md`/`INSTALL.md` на двух языках) не было выполнено: файлов `*_en.md` не было.
   Созданы `README_en.md` и `INSTALL_en.md`.
7. Имена логов с точностью до минуты могли перезаписываться; правило 4/5 переведено на секунды.
8. `docs/*.md` не имеют английских версий; вынесено в Backlog `04-plans.md`.

### 13.11.2026 12:21 MSK
Исправлено по утверждённому плану:
- `check-upstream.yml` переписан под VDS: `manual_tag`, `DEFAULT_TAG`, сравнение с `internal/config/version`, checklist, telegram.
- `merge.yml` и `stable.yml` получили каркасы с inputs и закомментированными триггерами.
- `scripts/setup.sh`: диспетчер через `case`, `exit` в ветках `case`, аргументы `--kernel` и `--local`, неинтерактивный режим.
- Версия приведена к `3.1.20260812-vds` в `src/version.h`, `internal/vds/src/version.h`, `internal/config/current`;
  `internal/config/version` оставлен `3.1.20260812`.
- `src/Makefile` и `internal/vds/src/Makefile` читают версию из `version.h`, git-дата убрана.
- Созданы `README_en.md` и `INSTALL_en.md`; `README.md` и `INSTALL.md` переведены на русский по умолчанию.
- `docs/*.md` остаются в Backlog до следующего этапа.

### 13.11.2026 14:34 MSK
Аудит `03-tasks.md` и сверка с `06-debug.md`. Подробности — `.agents/logs/202611131431-reports.md`.

1. `scripts/setup.sh`: пустой `-k` трактуется как `uname -r` (`setup.sh:115-119`) вместо обновления
   до последней версии ядра (`06-debug.md:40`); не перенесены `check_os`/`validate_os_ver`/`check_deps`
   из `install-amneziawg-kernel.sh:45-121`; нет явного неинтерактивного режима; неявный
   `dnf update -y` в `install_deps` (`setup.sh:72-76`).
2. `check-upstream.yml`: нет нормализации тега (`:54-57`); в issue указан `upstream_tag` вместо
   `upstream_ref` (`:83`); checklist требует ручного запуска `stable.yml` (`:87`), что запрещено
   `06-debug.md:49`; нет `TELEGRAM_NOTIFY` и секретов Environment; не запускает `merge.yml`.
3. `merge.yml`: `inputs` в блоке `env` (`:39-41`) — ошибка из `06-debug.md:12-22`;
   `upstream_ref`/`kernel_version` обязательны и версия ядра зашита (`:12-21`);
   `dry_run` через `inputs` даёт автоматический push при `workflow_run` (`:107`);
   автоматический триггер `workflow_run` (`:7-9`); нет вызова `stable.yml`; правило 11
   реализовано частично; версия из имени ветки (`:92`); токен в `.git/config` (`:57-58`).
4. `stable.yml`: активные `workflow_run` и `workflow_dispatch` (`:4-7`) при запрете обоих
   в `06-debug.md:49`; нет проверки успеха `merge.yml`; `stable` из `HEAD` вместо `master` (`:79`).
5. Все три workflows используют `ubuntu-latest` (`06-debug.md:42-45`) и не имеют переключателя
   `TELEGRAM_NOTIFY`/секретов Environment (`06-debug.md:23-24`).
6. `03-tasks.md`: задача «Архитектору» не была отражена в `04-plans.md`; статусы отсутствовали.
   Исправлено: статусы введены, закрытые пункты перенесены в отчёт, план — Phase C в `04-plans.md`.

### 13.11.2026 14:52 MSK
Реализация Phase C из `04-plans.md`. Отчёт — `.agents/logs/202611131452-reports.md`.
Пункты 1–5 записи 14:34 закрыты изменениями в коде; проверка запуском остаётся за владельцем
(правило 7).

1. `scripts/setup.sh`: пустой `-k` теперь ставит последнее ядро через
   `dnf install kernel kernel-devel kernel-headers`; добавлены `check_os`, `confirm`,
   неинтерактивный флаг `-y/--yes`; `dnf update` из `install_deps` убран; локальная сборка
   использует корень репозитория, а не текущий каталог.
2. `check-upstream.yml`: нормализация тега, `upstream_ref` в тексте issue, удалён ручной
   запуск `stable.yml`, добавлены `run_merge`, `TELEGRAM_NOTIFY` и окружение `telegram`,
   автоматические триггеры закомментированы.
3. `merge.yml`: inputs разрешаются отдельным шагом, значения по умолчанию статические,
   `dry_run=true` по умолчанию, автоматический `workflow_run` убран, `stable.yml` вызывается
   через `workflow_call`, реализовано сравнение корневых файлов с предыдущей версией upstream,
   токен не сохраняется в `.git/config`, runner `ubuntu-24.04`.
4. `stable.yml`: остался только `workflow_call`, ветка `stable` создаётся из `master`,
   добавлены окружение и уведомление.
5. Осталось внешнее действие владельца: создать окружение `telegram` и добавить в него
   `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`; задать repo variable `TELEGRAM_NOTIFY`.
   До создания окружения валидатор VS Code помечает `environment: telegram` как неизвестное.
6. Ограничение: `bash -n` и `shellcheck` на рабочей машине недоступны (WSL не установлен);
   YAML проверен разбором через `python yaml.safe_load`.

### 13.11.2026 12:18 MSK
Telegram-уведомления не отправлялись: в логе `131120261351-merge.yml.log:106-107`
`TELEGRAM_BOT_TOKEN` и `TELEGRAM_CHAT_ID` пустые, шаг молча делал `exit 0`.

Причина и исправление:
- секреты заведены в Repository secrets как `TELEGRAM_BOT_TOKEN` / `TELEGRAM_CHAT_ID`,
  но job были привязаны к окружению `telegram`, которого в репозитории нет;
- `environment: telegram` убран из `merge.yml`, `stable.yml` и `check-upstream.yml`;
- в каждом job объявлены короткие переменные `TG_TOKEN` и `TG_CHAT_ID` со значениями
  `${{ secrets.TELEGRAM_BOT_TOKEN }}` и `${{ secrets.TELEGRAM_CHAT_ID }}`;
- `secrets` нельзя использовать в `env` на уровне workflow, поэтому env размещён в job;
- при пустых секретах выводится `::warning::` с именами проверенных секретов;
- осталось проверить запуском: `workflow_dispatch` с `dry_run=true`.

Отдельно обнаружено в том же логе (`:88`): `git: command not found` в контейнере
`quay.io/centos/centos:stream10`, потому что шаг `Install bootstrap tools` стоит после
`Checkout VDS`. Требует отдельного исправления порядка шагов.
