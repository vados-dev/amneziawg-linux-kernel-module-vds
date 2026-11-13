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
