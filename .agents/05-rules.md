Translate
Show Original
Lang: ru
Engine: google
05 — Правила
Извлечено из файла AGENTS.md . Этот файл содержит проектную информацию.

Правила 3 ​​и 3b (AWG / туннельная архитектура) действуют в 02-architecture.md.

11 правил
0. Конфигурация клиента неприкосновенна — СТРОГИЙ (lucx.106+)
Законодательство: обновление информации от экспертной группы ( x-ui update/ web-update / first start after upgrade) НЕ ДОЛЖНО нарушать уже работающие входящие соединения или выпущенные клиентские конфигурации.

Никогда не изменяйте данные, попадающие в конфигурацию пользовательского клиента, без явного действия/запроса оператора на этом сервере .

Сюда входят (список не является исчерпывающим):

туннеля Адрес / Допустимые IP-адреса (AWG, WireGuard) — изменение IP-адреса означает, что клиенту необходимо повторно загрузить файл .conf.
ключи (закрытый/открытый/PSK), секреты, UUID, пароль
поле обфускации (S/H/HPK) должно совпадать с полями конечной точки/хоста/порта, если оно уже было предоставлено клиенту.
Включение/отключение узлов, маршрутов узлов, всего, что нарушает процесс установления соединения/трафика без щелчка оператора.
Строго запрещено (даже «только для сломленных» / «идемпотентных» / «ради общего блага»):

startup- / InitDB- / migrate-on-boot — операции, перезаписывающие адреса, ключи или настройки узлов/клиентов в работающей базе данных.
Автоматическое исправление / перераспределение / «восстановление» IP-адреса при запуске панели или согласовании (уроки lucx.91→92, lucx.105→106)
«Тихое» перераспределение при обновлении/сохранении входящих данных/клиенте «попутно»
Любая миграция релизов на зарубежных производственных серверах, изменяющая параметры клиента без согласия пользователя,
Допустимый:

Выделять новый IP-адрес/ключи следует только в том случае, если поле пустое (новый клиент / новое подключение с очищенным полем AllowedIPs).
Изменение IP-адреса при явном оператора изменении входящего адреса через кнопку в пользовательском интерфейсе (и документирование этого процесса).
Считывать каждый входящий IP-адрес для экспорта/QR-кода (не изменять).
Заполнение схемы/обратная заполнение без изменения значений (добавить ключ со значением по умолчанию, оставить существующий без изменений).
На сервере обнаружена ошибка соединения (buzzbleed peer): исправление происходит только по запросу оператора или при нажатии кнопки/SQL-запроса — не автоматически на каждом хосте при обновлении.

Перед слиянием/релизом агент должен спросить: «Запускается ли тестировщик?» x-ui update«На интерактивной панели с сотней клиентов — не потеряет ли кто-нибудь из них интернет или не придётся ли им заново скачивать файл .conf без их желания?» Если да, то не следует объединять изменения.

0b. Оверлей Vanilla 3x-ui священен — СТРОГО (lucx.119+)
Закон: установка LucX-UI поверх работающей стандартной базы данных 3x-ui ( /etc/x-ui/x-ui.dbбез переустановки, x-ui update(Установка поверх существующей) ДОЛЖНА отобразить панель и показать существующих клиентов/входящие звонки без сбоя.

Типичный путь тестирования: устанавливается MHSanaei/3x-ui → устанавливается LucX → открывается Clients / Inbounds. Любая регрессия в этом месте означает «форк не устанавливается».

Перед слиянием/выпуском агент должен задать вопрос: «Если мы возьмем свежую версию SQLite из исходного кода 3.7.x с клиентами WireGuard и wg_keep_alive INTEGER«И запустите наш исполняемый файл — работают ли страница «Клиенты» и запуск Xray?» Если нет — не объединяйте изменения.

Строго запрещено:

Изменение типа поля Go, сопоставленного с существующим столбцом вышестоящего уровня ( clients.*, inbounds.*, …) без sql.Scanner/ driver.Valuer водителя (или эквивалентный документ), который принимает устаревшую форму . Урок lucx.119: KeepAlive int→ KeepAliveValue string без Scan→ unsupported Scan, storing driver.Value type int64 into type *model.KeepAliveValueна каждом Find(&[]ClientRecord)— панель «Что-то пошло не так».
Предположим, что GORM AutoMigrate самостоятельно «расширит» INTEGER→TEXT в SQLite. В SQLite привязка осуществляется к значению: столбец остается INTEGER, драйвер возвращает значение. int64Для старых строк. Нужен Scanner, а не «type:text in the tag».
Схемы Zod/frontend, которые принимают только новый тип (например) keepAlive: z.number()) когда бэкэнд после записи в LucX может вернуть строку ( "25"/ "15-25") — Входящая форма редактирования не сохранится. Принимаются значения типа number|string (предварительная обработка), например normalizeAwgTimer/ optionalKeepAlive.
Миграции при запуске, которые в стандартной базе данных изменяют данные клиента (см. Правило 0). Расширение схемы / заполнение значений по умолчанию / создание новых пустых таблиц — ОК.
Требуется при изменении типа столбца / пользовательского типа:

Scan(+ Value(при записи) для всех форм драйвер возвращает значение в устаревшей базе данных: nil, int64, []byte, string, и float64при необходимости.
PostgreSQL: явно ALTER … TYPE text USING … перед AutoMigrate, если строгий тип не позволяет записывать новый формат ( migrate_awg_keepalive.go).
Регрессия: сканирование единиц + (если CGO) Findв таблице со столбцом типа INTEGER; десериализация JSON без использования дополнительных инструментов. {"keepAlive":25}; фронтенд анализирует число и строку.
Не стоит полагаться на утверждение «свежая база данных LucX работает без сбоев» — проверяйте путь к оверлею отдельно.
Разрешено / запрещено накладывать дополнительное покрытие:

Новые таблицы ( awg_outbounds) пустые, новые необязательные клавиши настроек с настройками по умолчанию.
Новый Protocoloneof values ​​(awg/naive/…) — не нарушать загрузку существующих строк.
Миграции protocol='awg'/ lucxTunnel_*— no-op — это стандартный режим.
См. шаблон 1n (отладка): сканирование wg_keep_alive.

1. Изоляция LUCX-HOOK
Все изменения в исходных файлах 3x-ui вносятся внутрь этого файла. // LUCX-HOOK/ // END LUCX-HOOKмаркеры. Никогда не изменяйте основной код 3x-ui вне этих маркеров без явного указания.

// LUCX-HOOK: Description of what this does
// ... your code ...
// END LUCX-HOOK
// LUCX-HOOK: Description
// ... your code ...
// END LUCX-HOOK
Бегать grep -rn "LUCX-HOOK" internal/ frontend/ install.shнайти все точки интегрирования.

2. Изолированные модули
Новая функциональность доступна ТОЛЬКО в:

Идти: internal/awg/— AWG sidecar (manager, process, instance, traffic, orphans)
Идти: internal/lucx/— подкаталоги: parser/, nodetype/, outbound_link/(Интеллектуальный кластер) wireguard/(стандартная рабочая группа ядра), tunnel/(боковые контейнеры туннеля: NaiveProxy, olcRTC, qWDTT, CSQTT, MasterDNSVPN, AIVPN, mieru, TrustTunnel)
Идти: internal/database/migrate_awg.go— миграция устаревшей базы данных
Идти: internal/database/migrate_geodata.go— Список активов Xray geodata.assets (Loyalsoldier + IR + RU + ROSCOM + GA)
Идти: internal/web/service/tunnel.go, internal/web/controller/tunnel.go, internal/web/job/tunnel_job.go— слой боковой стенки туннеля
Идти: internal/web/service/sidecar_outbound.go, internal/web/controller/sidecar_outbound.go— исходящие соединения клиента naive/mieru/TrustTunnel
Идти: internal/web/service/aivpn_clients.go— Управление ядром AIVPN — ретрансляция API (lucx.350)
Внешний интерфейс: frontend/src/schemas/protocols/inbound/awg.ts— Схема Зода
Внешний интерфейс: frontend/src/pages/inbounds/form/protocols/awg.tsx— Форма React
Внешний интерфейс: frontend/src/pages/inbounds/form/protocols/csqtt.tsx— Форма CSQTT
Внешний интерфейс: frontend/src/schemas/tunnel.ts, frontend/src/api/tunnels.ts, frontend/src/pages/tunnels/TunnelsPage.tsx— пользовательский интерфейс бокового туннеля
Оболочка: bin/install-awg-module.sh— Установка DKMS
Оболочка: bin/sourcecraft-release.sh— SourceCraft (Яндекс) выпустил архив в формате tarball.
Оболочка: bin/pack-sidecars.sh— ядра туннелей для каждой арки в архивах GitHub.
Точки интеграции ( model.go, db.go, web.go, runtime/local.go, service/xray.go, install.sh, inbound-defaults.ts, InboundFormModal.tsx, protocols/index.ts, primitives/protocol.ts, protocols/inbound/index.ts, api.go, routes.tsx, AppSidebar.tsx, queryKeys.ts, endpoints.ts) Получать только блоки LUCX-HOOK.

4. Параноидальная лесозаготовка
В журнале каждой критически важной операции добавляется префикс:

[LUCX-AWG]            — AWG service operations (legacy logAWG helper)
awg: <label> | <line> — sidecar process output (procLogWriter, matches mtproto)
5. Нет телеметрии
В старой версии LucX-UI было internal/lucx/telemt/Пакет для MTProto. Разработчики заменили его на собственный пакет. internal/mtproto/Не добавляйте код Telemt заново; используйте реализацию MTProto из исходного кода.

6. От tun2socks
В старой архитектуре использовался tun2socksДемон пользовательского пространства для соединения ядра AWG TUN со скрытым входящим SOCKS5. Архитектура sidecar делает его избыточным — Xray поддерживает собственный входящий TUN ( injectAwgEgress). Не добавляйте tun2socks повторно.

7. Дисциплина тестирования
Идти: go test ./internal/awg/... ./internal/lucx/... ./internal/database/... -count=1 -v
Внешний интерфейс: cd frontend && npm run typecheck && npm run lint
Тесты сервисов, зависящие от базы данных, требуют CGO_ENABLED=1(sqlite). Модульные тесты для логики AWG (экземпляр, состояние менеджера, inject, stripHiddenKeys) запускаются без cgo.
Добавьте тесты для каждой новой функции AWG: анализ экземпляра, стабильность отпечатка, рендеринг конфигурации, поведение внедрения, логика миграции.
8. Синхронизация с восходящим потоком
Процедура (проверено на v3.5.0→v3.6.0, 103 коммита из основного репозитория / 432 файла / 7 конфликтов; v3.6.0→v3.7.0 — инкрементальная: 7 коммитов / 19 файлов / 0 конфликтов):

git fetch origin --tagsзатем ответвление от нашей нынешней головы git merge --no-commit --no-ff origin/main.
Перед разрешением файла запишите количество маркеров LUCX-HOOK для каждого файла ( git grep -c "LUCX-HOOK"После слияния любой файл, количество которых уменьшилось, незаметно терял наш код — это единственный надежный детектор. Список файлов наложения: .agents/08-hooks.md.
Разрешайте конфликты ТОЛЬКО из терминала. Редактирование файла, находящегося в состоянии конфликта, приводит к тому, что IDE перезаписывает его из собственного кэша слияния и незаметно удаляет содержимое (v3.6.0: install.shПотеряны все 16 блоков LUCX-HOOK. db.go(потеряли новые функции вышестоящего уровня).
Решайте проблемы блок за блоком, никогда не используйте одну универсальную стратегию. Разработчики обычно добавляют код РЯДОМ с блоком хука, а не заменяют его, поэтому следует применять комплексный подход. --oursвыдает некомпилируемый код (v3.6.0: undefined: database.BackupSQLite). Общее правило: следует учитывать обе при добавлении соседнего вызова/теста/поля в исходный код стороны; нашу сторону следует учитывать только в тех случаях, когда наш блок является преднамеренной заменой (URL-адреса форков, prerelease: false).
Проверять: go build ./..., go vet ./..., go test ./internal/awg/... ./internal/lucx/..., bin/check-lucx.shи фронтенд lint+ typecheck+ vitest run --project=unit+ build.
Если в исходном коде был добавлен новый сквозной инвариантный тест, то его необходимо выполнить и для нашего кода — это было сделано в версии 3.6.0. frontend/src/test/i18n-dead-keys.test.ts, что требует, чтобы в каждой локали использовался точный набор ключей en-US (наши ключи AWG ранее использовались только в en+ru).
Примечание для Windows: internal/databaseтребуется CGO ( sqlite3.Backup), так go build ./...Сбой происходит без gcc — воспроизводится на исходном коде, а не в нашей регрессии. Релизные бинарные файлы предназначены только для Linux. CGO_ENABLED=1 в любом случае.

9. Фронтенд-стекинг
Разработчики переписали фронтенд с Vue на React + TypeScript + AntD v6 + Zod. AWG следует той же схеме:

frontend/src/schemas/protocols/inbound/awg.ts— Расписание Зода ( AwgInboundSettingsSchema), включает в себя mimicryProfile, browserProfile, outboundTag, routeThroughXray
frontend/src/pages/inbounds/form/protocols/awg.tsx— Форма AntD ( AwgFields), использует useFormContext(react-hook-form), FormField (нет Form.Item), message.useMessage() (нет App.useApp())
frontend/src/lib/xray/inbound-defaults.ts— createDefaultAwgInboundSettings(LUCX-HOOK)
frontend/src/lib/xray/inbound-link.ts— genAwgLink/ genAwgConfig(генерация ссылки для общего доступа + файла .conf, строки I1-I5 записаны как есть, без двойного переноса тегов CPS)
frontend/src/pages/clients/wireguardConfig.ts— buildAwgClientConfig(полный файл .conf клиента с блоком обфускации)
frontend/src/pages/clients/ClientQrModal.tsx— Панель AWG с QR-кодом + загрузка
Зарегистрировано в protocols/index.ts, schemas/inbound/index.ts, primitives/protocol.ts, InboundFormModal.tsx
10. Лицензия
Компоненты LucX-UI ( internal/awg/, internal/awg/cps/, internal/awg/signature/, internal/lucx/, internal/lucx/tunnel/aivpn*.go, internal/web/service/aivpn_clients.go, frontend/src/schemas/protocols/inbound/aivpn.ts, frontend/src/pages/inbounds/form/protocols/aivpn.tsx, internal/database/migrate_awg*.go, internal/database/migrate_geodata.go, internal/web/controller/kernel_wireguard.go, internal/web/job/kernel_wireguard_job.go, internal/web/service/kernel_wireguard.go, frontend/src/test/kernel-wireguard*.ts*, internal/web/controller/awg.go, internal/web/controller/awg_outbound.go, internal/web/controller/lucx.go, internal/web/controller/tunnel.go, internal/web/job/awg_job.go, internal/web/job/tunnel_job.go, internal/web/service/client_awg.go, internal/web/service/awg_outbound.go, internal/web/service/tunnel.go, frontend/src/schemas/protocols/inbound/awg.ts, frontend/src/schemas/tunnel.ts, frontend/src/api/tunnels.ts, frontend/src/pages/inbounds/form/protocols/awg.tsx, frontend/src/pages/inbounds/form/protocols/mieru.tsx, frontend/src/pages/inbounds/form/protocols/trusttunnel.tsx, frontend/src/schemas/protocols/inbound/mieru.ts, frontend/src/schemas/protocols/inbound/trusttunnel.ts, frontend/src/pages/inbounds/form/awg-inbound-id-context.ts, frontend/src/lib/mieru/presets.ts, frontend/src/pages/tunnels/TunnelsPage.tsx, frontend/src/pages/clients/wireguardConfig.ts, internal/lucx/tunnel/wgo.go, internal/lucx/tunnel/wgo_inbound.go, internal/lucx/wireguard/obfuscator.go, internal/lucx/wireguard/obfuscator_firewall_linux.go, internal/lucx/wireguard/obfuscator_firewall_other.go, internal/web/controller/wgo.go, internal/web/service/kernel_wgosocks_test.go, frontend/src/lib/wgo/link.ts, frontend/src/schemas/protocols/inbound/wgo.ts, frontend/src/schemas/protocols/inbound/wgosocks.ts, frontend/src/pages/inbounds/form/protocols/wgosocks.tsx, frontend/src/pages/inbounds/form/protocols/wgo-obfuscation.tsx, bin/install-awg-module.sh, bin/check-lucx.sh, bin/pre-push, bin/build-release.sh, bin/sourcecraft-release.sh) распространяются по лицензии PolyForm Noncommercial 1.0.0 . Бесплатно для личного и образовательного использования. Коммерческое использование (включая перепродажу VPN) требует явного письменного разрешения автора.

Оригинальный код 3x-ui по-прежнему распространяется под лицензией GPL-3.0.

Каждый новый файл, принадлежащий LucX, ДОЛЖЕН содержать заголовок SPDX (см. любой существующий файл в internal/awg/(для точного блока из 5 строк). Файлы с //go:buildВ тегах заголовок размещается после строки ограничения; в скриптах оболочки — после shebang. Полное разделение (какие файлы относятся к PolyForm, а какие к GPL, почему, коммерческие условия) задокументировано в файле LICENSING.md ; канонический текст лицензии — LICENSE-PolyForm-Noncommercial.txt . Файлы из исходного кода с блоками LUCX-HOOK остаются под лицензией GPL — никогда не добавляйте в них заголовки SPDX.

11. Язык документации — английский
Законодательство: агентская и проектная документация предоставляется только на английском языке .

Напишите на английском языке:

.agents/*, docs/progress.md, docs/LICENSING.mdа также любые другие документы по операциям с агентами/проектами.
Архитектурная карта, известные проблемы, шаблоны отладки, заметки о рабочем процессе.
Новые записи в docs/progress.mdа также внесение правок в существующий текст документа.
Исключения (не следует "переводить"):

Сообщения подтверждения — на русском языке (см. Соглашение о подтверждении подтверждения), если не указано иное.
Примечания к выпуску — блоки RU + EN для операторов (см. стиль примечаний к выпуску)
UI i18n — файлы локализации в internal/web/translation/оставаться многоязычным
Фразы пользователей/тестировщиков, строки логов или фиксированные текстовые описания продукта, которые по своей сути не являются английскими.
Не следует смешивать русскую и китайскую прозу в тексте. .agents/ или docs/progress.mdВ английском языке используется единый стиль, и токены сохраняются для каждой сессии агента.
