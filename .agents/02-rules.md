02 — Правила
Исторически извлечено из AGENTS.md; актуальный источник — этот файл.

1. Текущие задачи, поставленные агентам, в 03-tasks.md.

2. Текущие планы в 04-plans.md; агенты работают по нему. Ведёт архитектор.

3. Текущие проблемы агентов в 05-issues.md.

4. Текущие заметки агента в .agents/logs/$(date +'%Y%m%d%H%M%S')-notes.md.

5. Отчёты агента в .agents/logs/$(date +'%Y%m%d%H%M%S')-reports.md.

6. Результаты и проблемы, выявленные при отладке владельцем, в 06-debug.md.

7. Не выполнять самостоятельно и не автоматизировать запуски workflows, прописать, но закомментировать.

8. Документация, README.md и INSTALL.md — на двух языках, русский и английский, с переключением, по умолчанию русский.
   Русские файлы: README.md, INSTALL.md. Английские: README_en.md, INSTALL_en.md. Для docs/*.md — тот же суффикс _en.

9. Версия модуля WIREGUARD_VERSION хранится в src/version.h и является единственным источником истины.
   internal/config/version хранит версию upstream без суффикса, например 3.1.20260812.
   На выходе в src/version.h и internal/config/current всегда добавляется "-vds", например 3.1.20260812-vds.
   Пример version.h:
```code
#ifndef WIREGUARD_VERSION
#define WIREGUARD_VERSION "3.1.20260812-vds"
#endif
```
   src/Makefile читает версию из version.h; src/dkms.conf получает её при `make dkms-install`.
   Вручную дублировать версию в Makefile и dkms.conf не нужно.

10. Конечная версия тега VDS: "v[WIREGUARD_VERSION из предыдущего пункта]", например v3.1.20260812-vds.

11. Порядок перезаписи файлов при замене ветки master на новую версию из протестированной после слияния в merge.yml:
    - Очищаем ветку master от папок src, debian, kernel-tree-scripts и прочих, которые относились к upstream ранее.
    - Записываем в ветку master из временного, успешно протестированного образа, все папки и файлы обновлённого upstream.
    - Папку internal/vds/src удаляем и копируем на её место все изменённые файлы из src, для последующего сравнения с upstream.
    - Папки .github, .agents, docs и scripts не трогаем, с ними работаем только внутри ветки master.
    - В папку internal/config записываем новую текущую версию VDS в internal/config/current, записываем в internal/config/upstream ветку
      или тег из upstream и в internal/config/version текущую версию upstream.
    - Файлы в корне ветки master тоже не трогаем, с ними работаем только внутри ветки master, при условии,
      что в upstream ничего критичного не появилось/изменилось, в противном случае присылаем уведомление в telegram боте
      с подробным описанием изменений.

12. Уведомления Telegram управляются единым `notify_mode` (`none|inherit|changes|always`,
    default `none`) и глобальным kill-switch `vars.TELEGRAM_NOTIFY`. `none` и `inherit`
    означают «действует `vars.NOTIFY_MODE`» (при пустом значении — `changes`), `changes`
    и `always` переопределяют env. Один прогон — не более одного сообщения. Автозапуск
    `merge.yml` управляется отдельным `auto_merge`, а не флагом уведомлений. Имена инпутов —
    lowercase snake_case, резолвнутые значения — UPPERCASE `env`.
