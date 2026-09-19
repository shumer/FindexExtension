import Foundation

// Product labels follow the preferred language without changing global locale state.
enum ProductText {
    static func value(_ key: String) -> String {
        let language = Locale.preferredLanguages.first?.prefix(2) ?? "en"
        let index = ["en": 0, "ru": 1, "uk": 2, "pl": 3][String(language)] ?? 0
        let labels: [String: [String]] = [
            "hiddenFiles": ["Show/Hide Hidden Files", "Показать/скрыть скрытые файлы", "Показати/сховати приховані файли", "Pokaż/ukryj ukryte pliki"],
            "hiddenFinderUnavailable": ["Open Finder before changing hidden file visibility.", "Откройте Finder перед изменением видимости скрытых файлов.", "Відкрийте Finder перед зміною видимості прихованих файлів.", "Otwórz Finder przed zmianą widoczności ukrytych plików."],
            "hiddenPermission": ["Allow FinderPackAgent in System Settings > Privacy & Security > Accessibility, then try again.", "Разрешите FinderPackAgent в Системных настройках > Конфиденциальность и безопасность > Универсальный доступ, затем повторите попытку.", "Дозвольте FinderPackAgent у Системних параметрах > Приватність і безпека > Доступність, потім повторіть спробу.", "Zezwól FinderPackAgent w Ustawieniach systemowych > Prywatność i ochrona > Dostępność, a następnie spróbuj ponownie."],
            "hiddenFailed": ["Could not send the shortcut to Finder. Open a Finder window and try again.", "Не удалось отправить команду Finder. Откройте окно Finder и повторите попытку.", "Не вдалося надіслати команду Finder. Відкрийте вікно Finder і повторіть спробу.", "Nie udało się wysłać skrótu do Findera. Otwórz okno Findera i spróbuj ponownie."],
            "open": ["Open In", "Открыть в", "Відкрити у", "Otwórz w"],
            "gitRelative": ["Relative to Git Root", "Относительно корня Git", "Відносно кореня Git", "Względem katalogu Git"],
            "move": ["Move", "Переместить", "Перемістити", "Przenieś"],
            "chooseDestination": ["Choose Destination...", "Выбрать папку...", "Вибрати теку...", "Wybierz folder..."],
            "undoMove": ["Undo Last Move", "Вернуть последнее перемещение", "Скасувати останнє переміщення", "Cofnij ostatnie przeniesienie"],
            "cut": ["Cut", "Вырезать", "Вирізати", "Wytnij"],
            "pasteFiles": ["Paste (Copy)", "Вставить (копировать)", "Вставити (копіювати)", "Wklej (kopiuj)"],
            "pasteMove": ["Paste and Move", "Вставить и переместить", "Вставити й перемістити", "Wklej i przenieś"],
            "moveHere": ["Move Copied Files Here", "Переместить скопированные файлы сюда", "Перемістити скопійовані файли сюди", "Przenieś skopiowane pliki tutaj"],
            "copy": ["Copy Path", "Копировать путь", "Копіювати шлях", "Kopiuj ścieżkę"],
            "new": ["New File", "Новый файл", "Новий файл", "Nowy plik"],
            "posix": ["Absolute Path", "Абсолютный путь", "Абсолютний шлях", "Ścieżka bezwzględna"],
            "shellQuoted": ["Shell Quoted", "Для терминала", "Для термінала", "Dla terminala"],
            "fileURL": ["File URL", "URL файла", "URL файлу", "URL pliku"],
            "relative": ["Relative to Folder", "Относительно папки", "Відносно папки", "Względem folderu"],
            "homeRelative": ["Relative to Home", "Относительно домашней папки", "Відносно домашньої теки", "Względem katalogu domowego"],
            "name": ["File Name", "Имя файла", "Ім’я файлу", "Nazwa pliku"],
            "stem": ["Name Without Extension", "Имя без расширения", "Ім’я без розширення", "Nazwa bez rozszerzenia"],
            "parent": ["Parent Folder", "Родительская папка", "Батьківська тека", "Folder nadrzędny"],
            "loading": ["Templates unavailable", "Шаблоны недоступны", "Шаблони недоступні", "Szablony niedostępne"],
            "copied": ["Paths copied", "Пути скопированы", "Шляхи скопійовано", "Ścieżki skopiowane"],
            "created": ["File created", "Файл создан", "Файл створено", "Plik utworzony"],
            "failed": ["Action failed. Check folder access and agent registration.", "Не удалось выполнить действие. Проверьте доступ к папке и регистрацию помощника.", "Не вдалося виконати дію. Перевірте доступ до теки та реєстрацію помічника.", "Nie udało się wykonać działania. Sprawdź dostęp do folderu i rejestrację pomocnika."],
            "uncertain": ["The result is unknown. Check the folder or clipboard before trying again.", "Результат неизвестен. Проверьте папку или буфер обмена перед повтором.", "Результат невідомий. Перевірте теку або буфер обміну перед повтором.", "Wynik jest nieznany. Sprawdź folder lub schowek przed ponowną próbą."],
            "partial": ["Writing failed. A partial file may remain in the destination folder.", "Ошибка записи. В папке назначения мог остаться неполный файл.", "Помилка запису. У теці призначення міг залишитися неповний файл.", "Błąd zapisu. W folderze docelowym może pozostać niepełny plik."],
            "busy": ["An action is already running.", "Действие уже выполняется.", "Дія вже виконується.", "Działanie już trwa."],
            "notificationUncertain": ["Notification permission could not be confirmed. Check Notifications in System Settings.", "Не удалось проверить разрешение уведомлений. Проверьте раздел «Уведомления» в Системных настройках.", "Не вдалося перевірити дозвіл на сповіщення. Перевірте розділ «Сповіщення» в Системних параметрах.", "Nie udało się potwierdzić uprawnień do powiadomień. Sprawdź Powiadomienia w Ustawieniach systemowych."],
            "notificationWaiting": ["Waiting for notification permission. Respond to the macOS prompt if it appears.", "Ожидаем разрешение уведомлений. Ответьте на запрос macOS, если он появится.", "Очікуємо дозвіл на сповіщення. Дайте відповідь на запит macOS, якщо він з’явиться.", "Oczekiwanie na zgodę na powiadomienia. Odpowiedz na pytanie macOS, jeśli się pojawi."],
            "ok": ["OK", "ОК", "Гаразд", "OK"]
        ]
        return labels[key]?[index] ?? key
    }
}
