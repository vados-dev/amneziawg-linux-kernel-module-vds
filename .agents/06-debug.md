06 — Результаты отладки
Исторически извлечено из AGENTS.md; актуальный источник — этот файл.

### 13.11.2026
- Лог DKMS и разбор `src/compat/compat.h`: `.agents/logs/debug/compat-log.md`.
- Итог: падение сборки объясняется устаревшим build-деревом DKMS; актуальный `compat.h`
  с ISRHEL10-guards собирается на ядре 6.12.0-273.el10.

### 13:51
- merge.yml не запускается ошибки в логе .agents/logs/debug/131120261351-merge.yml.log.
Что это?
```code
  UPSTREAM_REF: ${{ inputs.upstream_ref }}
  KERNEL_VERSION: ${{ inputs.kernel_version }}
  VDS_BRANCH: ${{ inputs.vds_branch }}
```
должно быть:
```code
  UPSTREAM_REF: "master" # по умолчанию master, тут может быть и бранч и тэг
  KERNEL_VERSION: "" # по умолчанию пусто, т.е. последняя версия ядра
  VDS_BRANCH: "master" # по умолчанию master
```
Обрабатываться должно ниже и не хватает переменных для actions Repository[Environment] secrets, под telegram, я их сам пропишу.
Кстати переменну на включение и выключение тоже надо типа TELEGRAM_NOTIFY: true|false.

----
А это?
```code
  workflow_dispatch:
    inputs:
      upstream_ref:
        description: "Upstream tag or branch (for example v3.1.20260812)"
        required: true
        type: string
      kernel_version:
        description: "Target kernel version (for example 6.12.0-273.el10.x86_64)"
        required: true
        type: string
```
Ну заполните мне сразу хоть как-то, версия ядра не надо, она если пустая, пусть обновляется до последней

Это тоже косяк:
```code
"The ubuntu-latest label will migrate to Ubuntu 26 beginning October 19, 2026. For more information, see https://github.com/actions/runner-images/issues/14748"
```

- check-upstream.yml должен запускать merge.yml, либо вручную, сам merge.yml не должен запускаться автоматически.
- merge.yml должен запускать stable.yml и ждать пока тот не отработает корректно, если не отработал корректно, merge.yml завершается.
  Сам stable.yml не должен запускаться автоматически и даже вручную, он как часть merge.yml.

### 13.11.2026 12:18 MSK
- Telegram: секреты лежат в Repository secrets под именами `TELEGRAM_BOT_TOKEN` и `TELEGRAM_CHAT_ID`.
- В шагах используются короткие переменные `TG_TOKEN` и `TG_CHAT_ID`, объявленные на уровне job:
  `TG_TOKEN: ${{ secrets.TELEGRAM_BOT_TOKEN }}`, `TG_CHAT_ID: ${{ secrets.TELEGRAM_CHAT_ID }}`.
- Блок `environment: telegram` убран из всех job: Repository secrets доступны без окружения,
  а отсутствующее окружение давало пустые значения в логе `131120261351-merge.yml.log:106-107`.
- Контекст `secrets` недоступен в `env` на уровне workflow — только на уровне job/step,
  поэтому env вынесен в job, а не в корень файла.
- При отсутствии секретов шаг печатает `::warning::` с именами проверенных секретов вместо
  молчаливого `exit 0`.
