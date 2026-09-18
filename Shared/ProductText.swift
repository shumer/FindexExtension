import Foundation

// Product labels follow the preferred language without changing global locale state.
enum ProductText {
    static func value(_ key: String) -> String {
        let language = Locale.preferredLanguages.first?.prefix(2) ?? "en"
        let index = ["en": 0, "ru": 1, "uk": 2, "pl": 3][String(language)] ?? 0
        let labels: [String: [String]] = [
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
            "ok": ["OK", "ОК", "Гаразд", "OK"]
        ]
        return labels[key]?[index] ?? key
    }
}
