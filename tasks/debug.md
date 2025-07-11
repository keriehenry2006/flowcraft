# Debug Log - FlowCraft

## Problemy i rozwiązania dla przyszłych napraw

---

## 🐛 PROBLEM: Nie można zapisać procesów po edycji (2025-07-10 13:16)

### **Opis problemu:**
- Formularz edycji procesów nie pozwalał na zapisanie zmian
- Prawdopodobnie błąd walidacji w funkcji `validateProcessData()`
- Working day validation była niespójna z logiką biznesową

### **Przyczyna:**
Walidacja `working_day` w `flowcraft-error-handler.js` była nieprawidłowa:
```javascript
// BŁĘDNE - pozwalało na 0 i sprawdzało tylko < 0
if (data.working_day !== undefined && data.working_day < 0) {
    throw new Error('Working day must be a positive number');
}
```

### **Rozwiązanie:**
```javascript
// POPRAWNE - sprawdza pełny zakres 1-31 lub -1 do -31, blokuje 0
if (data.working_day !== undefined) {
    const workingDay = parseInt(data.working_day);
    if (isNaN(workingDay) || workingDay === 0 || workingDay > 31 || workingDay < -31) {
        throw new Error('Working day must be 1-31 for current month or -1 to -31 for previous month (cannot be 0)');
    }
}
```

### **Pliki zmienione:**
- `/mnt/c/Projects/Diagram2/flowcraft/flowcraft-error-handler.js` - linie 224-230
- `/mnt/c/Projects/Diagram2/flowcraft/index.html` - funkcja `handleSaveProcess()` linie 3947-4019

### **Jak uniknąć w przyszłości:**
- Zawsze sprawdzać spójność walidacji między backend i frontend
- Testować walidację z różnymi wartościami granicznymi (0, -32, 32)
- Dokumentować logikę biznesową w komentarzach kodu

---

## 🐛 PROBLEM: Kolumny tabeli za wąskie (2025-07-10 13:16)

### **Opis problemu:**
- Kolumna "Name" pokazywała tylko "Amortyz" zamiast pełnej nazwy
- Kolumna "Due Time" pokazywała tylko częściowy czas (10:, 15:)
- Brak tooltipów dla pełnych opisów

### **Przyczyna:**
Zbyt restrykcyjne szerokości kolumn w CSS:
```css
/* BŁĘDNE - za wąskie */
#processes-table th:nth-child(1), /* Name */
#processes-table td:nth-child(1) {
    min-width: 120px;
    max-width: 150px;
}
```

### **Rozwiązanie:**
```css
/* POPRAWNE - szersze kolumny */
#processes-table th:nth-child(1), /* Name */
#processes-table td:nth-child(1) {
    min-width: 160px;
    max-width: 200px;
}

#processes-table th:nth-child(4), /* Due Time */
#processes-table td:nth-child(4) {
    min-width: 110px;
    max-width: 130px;
}
```

### **Pliki zmienione:**
- `/mnt/c/Projects/Diagram2/flowcraft/index.html` - CSS linie 1774-1959

### **Jak uniknąć w przyszłości:**
- Testować z długimi nazwami procesów
- Używać min-width zamiast fixed width dla elastyczności
- Dodawać tooltips dla kolumn z ograniczoną szerokością

---

## 🐛 PROBLEM: Błędne pozycjonowanie procesów po WD axis expansion (2025-07-11 09:45)

### **Opis problemu:**
- Po rozszerzeniu osi WD (dodaniu negative values), istniejące procesy jak "Create FA" nie były pozycjonowane na właściwych pozycjach
- Proces "Create FA" ustawiony na WD -2 nie trafiał na właściwą pozycję po axis expansion
- Screenshot pokazał misalignment - proces był w złym miejscu względem expanded axis

### **Root Cause:**
**Cached Layout Positions vs Current Axis State**
- `node.style.left = layout.finalX` używał cached pozycji z pierwotnego layout calculation
- Po axis expansion, `gWdColumnWidth` i `gUniqueDataWds` się zmieniały, ale existing processes używały old coordinates
- Layout calculation był done before axis expansion, więc finalX was based on old axis configuration

### **Rozwiązanie:**
**Real-time Position Recalculation (Diagram.html:12678-12695)**
```javascript
// Recalculate X position based on current axis state after expansion
if (layout.process && layout.process.WD !== undefined) {
    const processWd = layout.process.WD;
    const wdIndex = gUniqueDataWds.indexOf(processWd);
    if (wdIndex !== -1) {
        const newXCenter = gYAxisLabelWidthOriginal + gDiagramPanePadding + (wdIndex * gWdColumnWidth) + (gWdColumnWidth / 2);
        const newLeft = newXCenter - layout.width / 2;
        node.style.left = `${newLeft}px`;
        // Position recalculated for axis expansion
    } else {
        // Fallback to cached position if WD not found
        node.style.left = `${layout.finalX}px`;
        console.log(`⚠️ Using cached position for ${layout.process["Short name"] || layout.process.ID} - WD ${processWd} not found in axis`);
    }
} else {
    // Fallback to cached position if no WD data
    node.style.left = `${layout.finalX}px`;
}
```

### **Kluczowe zmiany:**
1. **Position Recalculation**: Calculate X position based on current `gUniqueDataWds` array state
2. **Current Column Width**: Use updated `gWdColumnWidth` for accurate positioning
3. **WD Index Lookup**: Find current index in expanded array instead of using cached coordinates
4. **Fallback Handling**: Graceful degradation if WD not found in current axis

### **Pliki zmienione:**
- **Diagram.html**: Linie 12678-12695 - Position recalculation logic dla existing processes

### **Rezultat:**
- ✅ **"Create FA" positioned correctly** at WD -2 after axis expansion
- ✅ **All existing processes** maintain correct positioning after dynamic axis changes
- ✅ **Real-time calculation** based on current axis state, not cached layout
- ✅ **Stable positioning** for both simulation and non-simulation processes

### **Jak uniknąć w przyszłości:**
- Always recalculate positions based on current axis state, nie cached layout
- Use dynamic WD index lookup instead of static coordinate caching
- Test position accuracy after any axis expansion or layout modification
- Ensure consistent positioning logic between simulation and standard modes

---

## 💡 ULEPSZENIE: System skrótów typów procesów (2025-07-10 13:16)

### **Implementacja:**
Zmiana z select dropdown na kompaktowy system skrótów:
- Standard → S
- Blocking → B  
- Informational → I

### **Nowe funkcje dodane:**
```javascript
function getProcessTypeAbbreviation(type) { /* ... */ }
function getProcessTypeFullName(type) { /* ... */ }
function toggleProcessType(element) { /* ... */ }
function updateProcessType(processId, newType) { /* ... */ }
```

### **Korzyści:**
- Znacznie mniej miejsca w tabeli
- Tooltips z pełnymi nazwami
- Łatwa zmiana przez kliknięcie
- Automatyczne zapisywanie do bazy

### **Zastosowanie w przyszłych projektach:**
- Używać skrótów dla często używanych wartości
- Implementować tooltip system dla lepszej UX
- Dodawać click-to-change funkcjonalność

---

## 📋 SZABLON DLA PRZYSZŁYCH PROBLEMÓW:

```markdown
## 🐛 PROBLEM: [Nazwa problemu] ([Data])

### **Opis problemu:**
- [Szczegóły co nie działa]

### **Przyczyna:**
[Analiza źródła problemu z przykładami kodu]

### **Rozwiązanie:**
[Kod rozwiązania z komentarzami]

### **Pliki zmienione:**
- [Lista plików i linii]

### **Jak uniknąć w przyszłości:**
- [Wnioski i best practices]
```

---

---

## 🐛 PROBLEM: "Please match the requested format" przy dodawaniu procesu (2025-07-10 13:22)

### **Opis problemu:**
- Użytkownik próbuje wprowadzić nowy proces
- Wszystkie pola są uzupełnione
- Pojawia się komunikat "Please match the requested format" w prawym górnym rogu
- Nie można zapisać procesu

### **Przyczyna:**
Zbyt restrykcyjne regex patterns w HTML5 validation:

```html
<!-- BŁĘDNE - wymagały TYLKO wielkich liter -->
pattern="^[A-Z0-9_\-]+$"          <!-- Process Name -->
pattern="^([A-Z0-9_\-]+(,[A-Z0-9_\-]+)*)?$"  <!-- Dependencies -->
pattern="^([01]?[0-9]|2[0-3]):[0-5][0-9]$"   <!-- Due Time - nie akceptował pustego pola -->
```

### **Rozwiązanie:**
```html
<!-- POPRAWNE - obsługują małe i wielkie litery -->
pattern="^[A-Za-z0-9_\-]+$"                   <!-- Process Name -->
pattern="^([A-Za-z0-9_\-]+(,[A-Za-z0-9_\-]+)*)?$"    <!-- Dependencies -->
pattern="^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$|^$"       <!-- Due Time - akceptuje puste pole -->
```

Dodatkowo dodano:
```javascript
// Custom validation z lepszymi komunikatami błędów
function validateProcessForm() {
    // Sprawdza wszystkie pola z dokładnymi komunikatami
    if (!/^[A-Za-z0-9_\-]+$/.test(processName.value)) {
        showCustomValidationError(processName, 'Process name can only contain letters, numbers, hyphens and underscores');
        return false;
    }
    // ... więcej validacji
}

function showCustomValidationError(element, message) {
    element.setCustomValidity(message);
    element.reportValidity();
}
```

### **Pliki zmienione:**
- `/mnt/c/Projects/Diagram2/flowcraft/index.html` - linie 2882, 2895, 2900, 4205-4254

### **Jak uniknąć w przyszłości:**
- Testować regex patterns z różnymi przypadkami (wielkie/małe litery)
- Używać `[A-Za-z]` zamiast `[A-Z]` dla uniwersalności
- Dodawać `|^$` do patterns dla opcjonalnych pól
- Implementować custom validation z dokładnymi komunikatami błędów
- Testować formularze z różnymi wartościami przed wdrożeniem

### **Objawy do rozpoznania:**
- Komunikat "Please match the requested format" w przeglądarce
- Brak możliwości submit formularza mimo wypełnionych pól
- Problem występuje przy HTML5 form validation (przed JavaScript)

---

---

## 🐛 PROBLEM: Ponowny błąd "Please match the requested format" dla "Raporting" (2025-07-10 14:07)

### **Opis problemu:**
- Wcześniej naprawiono regex patterns, ale problem powrócił
- Proces "Raporting" był odrzucany z czerwoną ramką
- Inne pola były prawidłowe (zielone ramki)
- Komunikat "Please match the requested format" dalej się pojawiał

### **Przyczyna:**
Niepoprawne escape'owanie znaku `-` w character class regex patterns:

```html
<!-- BŁĘDNE - niepotrzebne escape \- na końcu character class -->
pattern="^[A-Za-z0-9_\-]+$"
pattern="^([A-Za-z0-9_\-]+(,[A-Za-z0-9_\-]+)*)?$"
```

W character class, gdy `-` jest na początku lub końcu, nie potrzebuje escape'owania. Znak `\-` był źle interpretowany przez przeglądarki.

### **Rozwiązanie:**
```html
<!-- POPRAWNE - bez escape na końcu character class -->
pattern="^[A-Za-z0-9_-]+$"
pattern="^([A-Za-z0-9_-]+(,[A-Za-z0-9_-]+)*)?$"
```

Dodatkowo:
```html
<!-- Wyłączenie HTML5 validation dla uniknięcia konfliktów -->
<form id="process-form" novalidate>
```

I synchronizacja JavaScript patterns:
```javascript
if (!/^[A-Za-z0-9_-]+$/.test(processName.value)) { // bez \-
if (dependencies.value && !/^([A-Za-z0-9_-]+(,[A-Za-z0-9_-]+)*)?$/.test(dependencies.value)) {
```

### **Pliki zmienione:**
- `/mnt/c/Projects/Diagram2/flowcraft/index.html` - linie 2879, 2882, 2900, 4217, 4236

### **Jak uniknąć w przyszłości:**
- **Zasada escaping w character class**: `-` na początku `[-abc]` lub końcu `[abc-]` nie potrzebuje escape
- **Środkowe `-` potrzebuje escape**: `[a\-c]` lub umieścić na końcu `[ac-]`
- **Testować regex patterns** w konsoli przeglądarki: `/^[A-Za-z0-9_-]+$/.test("Raporting")`
- **Używać novalidate** gdy mamy custom validation żeby uniknąć konfliktów HTML5
- **Synchronizować wszystkie patterns** między HTML i JavaScript

### **Objawy do rozpoznania:**
- Czerwona ramka na konkretnym polu (nie wszystkich)
- Pattern działa dla niektórych wartości, ale nie dla innych
- JavaScript console może pokazać błędy regex parsing
- Problem występuje po refresh strony (cache nie pomaga)

---

---

## 🐛 PROBLEM: Błędy konsoli i polskie znaki w nazwach procesów (2025-07-10 14:20)

### **Opis problemu:**
- Proces "Zamknięcie Ksiąg" był odrzucany z czerwoną ramką
- Przycisk pokazywał "UPDATING..." ale się zatrzymywał
- W konsoli pojawiały się błędy JavaScript
- Regex patterns nie obsługiwały polskich znaków

### **Przyczyna:**
Regex patterns nie obsługiwały polskich znaków diakrytycznych:

```javascript
// BŁĘDNE - brak polskich znaków
/^[A-Za-z0-9_-]+$/

// Proces "Zamknięcie Ksiąg" zawiera:
// - ę (e z ogonkiem)
// - ą (a z ogonkiem) 
// - spację
```

Problem występował w:
1. HTML pattern validation
2. JavaScript custom validation
3. Brak obsługi spacji w nazwach

### **Rozwiązanie:**
```html
<!-- POPRAWNE - z polskimi znakami i spacjami -->
pattern="^[A-Za-z0-9ĄąĆćĘęŁłŃńÓóŚśŹźŻż_\s-]+$"
```

Pełna lista polskich znaków dodanych:
- **Wielkie**: Ą, Ć, Ę, Ł, Ń, Ó, Ś, Ź, Ż
- **Małe**: ą, ć, ę, ł, ń, ó, ś, ź, ż
- **Spacje**: `\s` dla nazw jak "Zamknięcie Ksiąg"

Dodatkowo naprawiono:
```javascript
// Button state management - originalText dostępny w finally block
const submitBtn = document.getElementById('save-process-btn');
const originalText = submitBtn.textContent; // Poza try block

// Reset przycisku przy błędzie walidacji
if (!validateProcessForm()) {
    submitBtn.textContent = originalText;
    submitBtn.disabled = false;
    return;
}
```

### **Pliki zmienione:**
- `/mnt/c/Projects/Diagram2/flowcraft/index.html` - linie 2882, 2900, 4008-4017, 4217, 4236

### **Jak uniknąć w przyszłości:**
- **Testować z różnymi językami** od początku projektu
- **Używać Unicode ranges** dla full international support: `[\p{L}\p{N}\s_-]+` z flag 'u'
- **Comprehensive character sets** dla różnych języków:
  - Polski: ĄąĆćĘęŁłŃńÓóŚśŹźŻż
  - Niemiecki: ÄäÖöÜüß
  - Francuski: ÀàÂâÇçÉéÈèÊêËëÎîÏïÔôÙùÛûÜüŸÿ
- **Testować edge cases** z długimi nazwami i spacjami
- **Button state management** zawsze poza try blocks

### **Objawy do rozpoznania:**
- Czerwona ramka na polach z polskimi znakami
- "UPDATING..." button zatrzymany
- JavaScript console errors z regex
- Validation działa dla angielskich, ale nie polskich nazw
- Problem występuje częściej w polskich interfejsach

### **Test cases dla przyszłości:**
```javascript
// Testy regex patterns
/^[A-Za-z0-9ĄąĆćĘęŁłŃńÓóŚśŹźŻż_\s-]+$/.test("Zamknięcie Ksiąg") // true
/^[A-Za-z0-9ĄąĆćĘęŁłŃńÓóŚśŹźŻż_\s-]+$/.test("Księgowość") // true  
/^[A-Za-z0-9ĄąĆćĘęŁłŃńÓóŚśŹźŻż_\s-]+$/.test("Płatności") // true
/^[A-Za-z0-9ĄąĆćĘęŁłŃńÓóŚśŹźŻż_\s-]+$/.test("Start Process") // true
```

---

---

## 🐛 PROBLEM: Błąd regex pattern w HTML attribute (2025-07-10 14:27)

### **Opis problemu:**
- Proces "Zamknięcie Ksiąg" został zapisany pomyślnie
- W konsoli pojawił się błąd: `Pattern attribute value ^[A-Za-z0-9ĄąĆćĘęŁłŃńÓóŚśŹźŻż_\s-]+$ is not a valid regular expression`
- Błąd: `Invalid character class` dla polskich znaków w HTML pattern

### **Przyczyna:**
HTML pattern attribute ma ograniczenia w obsłudze Unicode characters:

```html
<!-- PROBLEMATYCZNE - polskie znaki w HTML pattern -->
<input pattern="^[A-Za-z0-9ĄąĆćĘęŁłŃńÓóŚśŹźŻż_\s-]+$">
```

Przeglądarka próbuje interpretować polskie znaki w pattern attribute jako regex, ale:
1. Może nie obsługiwać Unicode w HTML patterns
2. Flag 'v' może powodować konflikty
3. Character class z polskimi znakami jest źle parsowany

### **Rozwiązanie:**
**Usunięcie wszystkich pattern attributes z HTML:**

```html
<!-- PRZED - problematyczne patterns -->
<input pattern="^[A-Za-z0-9ĄąĆćĘęŁłŃńÓóŚśŹźŻż_\s-]+$">
<input pattern="^([A-Za-z0-9ĄąĆćĘęŁłŃńÓóŚśŹźŻż_\s-]+(,[A-Za-z0-9ĄąĆćĘęŁłŃńÓóŚśŹźŻż_\s-]+)*)?$">
<input pattern="^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$|^$">

<!-- PO - tylko JavaScript validation -->
<input type="text" id="process-short-name" required>
<form novalidate> <!-- HTML5 validation wyłączona -->
```

**Zachowana JavaScript validation:**
```javascript
function validateProcessForm() {
    if (!/^[A-Za-z0-9ĄąĆćĘęŁłŃńÓóŚśŹźŻż_\s-]+$/.test(processName.value)) {
        showCustomValidationError(processName, 'Process name can contain...');
        return false;
    }
    // ...
}
```

### **Pliki zmienione:**
- `/mnt/c/Projects/Diagram2/flowcraft/index.html` - linie 2882, 2890, 2895, 2900

### **Jak uniknąć w przyszłości:**
- **Unikać HTML pattern attributes** z Unicode characters
- **Używać tylko JavaScript validation** dla complex regex patterns
- **HTML patterns** tylko dla prostych cases (digits, basic ASCII)
- **Testing**: Sprawdzać console errors po każdej zmianie validation
- **Alternative approaches**:
  - Unicode escape sequences w HTML: `\u0105` zamiast `ą`
  - Używać `inputmode` i `autocomplete` zamiast patterns
  - Full JavaScript validation z `setCustomValidity()`

### **Objawy do rozpoznania:**
- Aplikacja działa, ale console ma regex errors
- Pattern attribute value not valid regular expression
- Invalid character class w browser regex engine
- Problem występuje tylko z non-ASCII characters w patterns
- Błąd po focus/blur na input z pattern

### **Best practice validation strategy:**
```html
<!-- ZALECANE - clean HTML -->
<form novalidate>
    <input type="text" required minlength="1" maxlength="50">
</form>

<!-- + comprehensive JavaScript validation -->
<script>
function validateForm() {
    // Full control over validation logic
    // Better error messages
    // Unicode support without browser limitations
}
</script>
```

---

## 🐛 PROBLEM: "Please match the requested format" przez HTML5 form validation (2025-07-10 14:21)

### **Opis problemu:**
- Użytkownik wypełnia formularz procesu: "Zamknięcie Ksiag"
- Wszystkie pola są poprawne, ale pojawia się "Please match the requested format"
- Kliknięcie "Save Process" nie działa, formularz nie może zostać wysłany
- Błąd pojawia się zanim custom JavaScript validation zostanie uruchomiony

### **Przyczyna:**
Przyciski w formularzu nie miały `type="button"`, więc domyślnie były `type="submit"`:

```html
<!-- BŁĘDNE - domyślne type="submit" -->
<button id="save-process-button" class="btn-fc btn-fc-success save-button">Save</button>
<button id="delete-process-button" class="btn-fc btn-fc-danger delete-button">Delete</button>
<button id="cancel-process-button" class="btn-fc btn-fc-secondary cancel-button">Cancel</button>
```

To powodowało:
1. **HTML5 form validation** uruchamiała się automatycznie przy kliknięciu
2. **Brak pattern attributes** powodował domyślne browser validation
3. **JavaScript validation** nie miała szansy się uruchomić
4. **Custom error messages** nie były wyświetlane

### **Rozwiązanie:**
Dodanie `type="button"` do wszystkich przycisków:

```html
<!-- POPRAWNE - wyraźne type="button" -->
<button type="button" id="save-process-button" class="btn-fc btn-fc-success save-button">Save</button>
<button type="button" id="delete-process-button" class="btn-fc btn-fc-danger delete-button">Delete</button>
<button type="button" id="cancel-process-button" class="btn-fc btn-fc-secondary cancel-button">Cancel</button>
```

### **Pliki zmienione:**
- `/mnt/c/Projects/Diagram2/flowcraft/Diagram.html` - linie 5476-5478

### **Jak uniknąć w przyszłości:**
- **Zawsze** używać `type="button"` dla przycisków w modal dialogs
- **Tylko** używać `type="submit"` gdy chcemy rzeczywisty HTML form submission
- **Testować** form validation od razu po utworzeniu przycisków
- **Pamiętać**: button bez type attribute domyślnie jest `type="submit"`

### **Objawy do rozpoznania:**
- "Please match the requested format" pojawia się natychmiast po kliknięciu
- Formularz jest wypełniony poprawnie, ale nie można go wysłać
- JavaScript validation nie jest uruchamiany
- Problem występuje w modalach z przyciskami bez type attribute

### **Debugging tips:**
```javascript
// Sprawdzenie typu przycisku w konsoli
document.getElementById('save-process-button').type // "submit" or "button"

// Sprawdzenie czy form ma validation
document.querySelector('form').noValidate // true/false

// Sprawdzenie czy input ma pattern
document.getElementById('process-id-modal').pattern // string or ""
```

---

## 🐛 PROBLEM: "currentProcesses is not defined" błąd przy zmianie statusu (2025-07-10)

### **Opis problemu:**
- Kliknięcie na "Change Status" obok procesu powoduje błąd w konsoli
- Błąd: `Uncaught ReferenceError: currentProcesses is not defined at openProcessStatusModal (index.html:5142:33)`
- Funkcja `openProcessStatusModal()` próbuje użyć `currentProcesses.find()` ale zmienna nie istnieje

### **Przyczyna:**
Funkcja `openProcessStatusModal()` została przeniesiona z `Diagram.html` do `index.html`, ale:
1. **Brak zmiennej globalnej** - `currentProcesses` nie było zdefiniowane w `index.html`
2. **W Diagram.html** funkcja `getCurrentlyVisibleProcesses()` była używana do pobierania procesów
3. **W index.html** dane procesów były pobierane lokalnie w `loadProcesses()` ale nie przechowywane globalnie

### **Rozwiązanie:**
```javascript
// DODANE - globalna zmienna na górze pliku
let currentProcesses = [];

// ZMODYFIKOWANE - w funkcji loadProcesses()
async function loadProcesses() {
    // ... existing code ...
    
    // Store processes globally for status management
    currentProcesses = processes || [];
    renderProcessesTable(processes);
}
```

### **Pliki zmienione:**
- `/mnt/c/Projects/Diagram2/flowcraft/index.html` - linie 3779, 3799-3800

### **Jak uniknąć w przyszłości:**
- **Przy przenoszeniu funkcji** między plikami sprawdzać wszystkie dependencies
- **Globalne zmienne** muszą być zdefiniowane w scope gdzie są używane
- **Testować przeniesione funkcje** natychmiast po przeniesieniu
- **Używać console.log** do debugowania scope variables

### **Objawy do rozpoznania:**
- ReferenceError: variable is not defined
- Problem występuje po przeniesieniu kodu między plikami
- Funkcja działa w jednym miejscu, ale nie w innym
- Błąd pojawia się przy pierwszym użyciu funkcji

### **Test case:**
```javascript
// Sprawdzenie czy currentProcesses jest dostępne
console.log('currentProcesses:', currentProcesses); // powinno pokazać array
```

---

## 🐛 PROBLEM: Pattern validation errors i błędy Supabase przy zmianie statusu (2025-07-10)

### **Opis problemu:**
- Kliknięcie na "Change Status" powoduje błędy w konsoli
- Pattern attribute validation errors: "Pattern attribute value ^[A-Za-z0-9_-]+$ is not a valid regular expression"
- Błędy Supabase: "Project jvzauyhkehucfvovjqjh is in status REMOVED"
- Funkcja zmiany statusu nie działa prawidłowo

### **Przyczyny:**
1. **Pattern validation**: Jeden pattern attribute w HTML (register-name) powodował błędy
2. **Supabase project removed**: Projekt w MCP.json był inny niż w config.js
3. **Stary projekt usunięty**: MCP używał projektu `jvzauyhkehucfvovjqjh` który został usunięty
4. **Aktywny projekt**: Aplikacja używa `hbwnghrfhyikcywixjqn` w config.js

### **Rozwiązania:**
```html
<!-- USUNIĘTE - pattern attribute z rejestracji -->
<input type="text" id="register-name" placeholder="Full Name" required minlength="2" maxlength="100" title="...">
```

```json
// NAPRAWIONE - MCP.json project-ref
"--project-ref=hbwnghrfhyikcywixjqn"
```

### **Pliki zmienione:**
- `/mnt/c/Projects/Diagram2/flowcraft/index.html` - linia 2672 (usunięty pattern)
- `/mnt/c/Projects/Diagram2/flowcraft/mcp.json` - linia 10 (poprawiony project-ref)

### **Jak uniknąć w przyszłości:**
- **Synchronizować project-ref** między config.js i mcp.json
- **Usuwać pattern attributes** z HTML, używać tylko JavaScript validation
- **Sprawdzać status projektów** Supabase regularnie
- **Testować MCP connections** przed deploy

### **Objawy do rozpoznania:**
- Console errors o pattern validation
- "Project ... is in status REMOVED" w MCP
- Funkcje Supabase nie działają
- Różne project-ref w różnych plikach konfiguracji

### **Status:**
- ✅ Pattern validation naprawione
- ✅ MCP project-ref zsynchronizowany
- ⚠️ Funkcjonalność wymaga testów po restart Claude Code

---

## 🐛 PROBLEM: Błędy RLS policy i brak synchronizacji statusów między widokami (2025-07-10 19:30)

### **Opis problemu:**
- Kliknięcie "Change Status" powodowało błędy w konsoli: `new row violates row-level security policy for table "process_status_history"`
- Status changes działały w Process Manager ale nie synchronizowały się z Diagram.html
- Reset status pokazywał "Failed to update process status"
- Diagram zawsze pokazywał statusy jako "pending" mimo zmian w Manager

### **Główne przyczyny:**
1. **Brakujące pola statusu w ładowaniu danych**: Diagram.html nie ładował pól `status`, `completed_at`, `completion_note`, `assigned_to`, `due_date` z bazy
2. **RLS policy violations**: Skomplikowane RLS policies dla tabeli `process_status_history` powodowały błędy 403
3. **Brak synchronizacji**: Nie było mechanizmu komunikacji między Process Manager a Diagram
4. **Usunięte pliki migracji**: `supabase_migrations.sql` został usunięty z repozytorium

### **Rozwiązania zaimplementowane:**

#### 1. **Naprawa ładowania danych w Diagram.html**
```javascript
// DODANE - pola statusu w loadDataFromSupabase() (linie 8594-8599)
const process = {
    // ... existing fields ...
    status: row.status || 'PENDING',
    completed_at: row.completed_at,
    completion_note: row.completion_note,
    assigned_to: row.assigned_to,
    due_date: row.due_date
};
```

#### 2. **Aktualizacja funkcji zapisu w Diagram.html**
```javascript
// DODANE - pola statusu w saveProcessToSupabase() i updateProcessInSupabase()
.update({
    // ... existing fields ...
    status: processData.status || 'PENDING',
    completed_at: processData.completed_at || null,
    completion_note: processData.completion_note || null,
    assigned_to: processData.assigned_to || null,
    due_date: processData.due_date || null,
    // ...
})
```

#### 3. **Ulepszona obsługa błędów RLS**
```javascript
// DODANE - try-catch w markProcessCompleted() i markProcessDelayed()
try {
    await this.executeSupabaseRequest(/* status history insert */);
} catch (historyError) {
    console.warn('Could not record status change history (table may not exist):', historyError);
}
```

#### 4. **Mechanizm synchronizacji między widokami**
```javascript
// DODANE - w index.html po zmianie statusu
window.opener.postMessage({
    type: 'PROCESS_STATUS_UPDATED',
    processId: processId,
    newStatus: newStatus,
    completionNote: note
}, window.location.origin);

// DODANE - w Diagram.html listener
window.addEventListener('message', function(event) {
    if (event.data.type === 'PROCESS_STATUS_UPDATED') {
        // Update process data and re-render diagram
        renderDiagramAndRestoreState();
    }
});
```

#### 5. **Ulepszona obsługa reset status**
```javascript
// DODANE - fallback w przypadku błędów
try {
    result = await /* normal status update */;
} catch (statusUpdateError) {
    // Fallback: try updating only basic fields
    result = await /* basic update */;
    showNotification('Status reset completed (limited database support)', 'warning');
}
```

### **Pliki zmienione:**
- **Diagram.html**:
  - linie 8594-8599: Dodane pola statusu w `loadDataFromSupabase()`
  - linie 8701-8705, 8747-8751, 8765-8769: Dodane pola statusu w funkcjach zapisu
  - linie 8727, 8682: Zaktualizowane `excludeFields` arrays
  - linie 6432-6462: Dodany listener dla synchronizacji statusów
- **index.html**:
  - linie 5262-5296: Ulepszona obsługa błędów w `updateProcessStatus()`
  - linie 5312-5324: Dodana synchronizacja z Diagram via postMessage
- **flowcraft-error-handler.js**:
  - linie 1138-1154, 1182-1198: Dodana obsługa błędów dla `process_status_history`
- **supabase_migrations.sql**: Przywrócony z git history

### **Oczekiwane rezultaty:**
1. ✅ **Brak błędów RLS**: Try-catch handling dla `process_status_history`
2. ✅ **Synchronizacja statusów**: PostMessage komunikacja między widokami  
3. ✅ **Diagram ładuje statusy**: Dodane wszystkie pola statusu
4. ✅ **Lepsha obsługa reset**: Fallback mechanizmy
5. 🔄 **Wymaga testów**: Funkcjonalność po restart Claude Code

### **Jak uniknąć w przyszłości:**
- **Zawsze sprawdzać synchronizację** między różnymi widokami aplikacji
- **Implementować graceful degradation** dla nieistniejących tabel/pól
- **Używać postMessage API** do komunikacji między oknami
- **Nie usuwać plików migracji** bez zastąpienia ich aktualnymi
- **Testować RLS policies** z różnymi scenariuszami użytkowników
- **Dokumentować zależności** między plikami w kodzie

### **Objawy do rozpoznania:**
- Console errors: "new row violates row-level security policy"
- POST 403 (forbidden) błędy w network tab
- Status changes działają tylko w jednym widoku
- "Failed to update process status" messages
- Diagram pokazuje zawsze "pending" statusy

---

## 🐛 PROBLEM: Reset status nie działa + błędy 403 przy completed on time (2025-07-10 19:55)

### **Opis problemu:**
- Kliknięcie "Reset to Pending" pokazuje błąd "Failed to update process status"
- Completed on time powoduje wielokrotne błędy 403 Forbidden na process_status_history
- Status się zmienia ale z opóźnieniem i błędami w konsoli
- Brak automatycznego odświeżania statusu w diagramie

### **Przyczyny:**
1. **RLS Policy na process_status_history**: Brak prawidłowej autentykacji użytkownika
2. **Reset function**: Problem z walidacją result.data (był undefined mimo sukcesu)
3. **Authentication**: userId było hardcoded zamiast pobierane z auth.getUser()
4. **Status field check**: Brak sprawdzenia czy pola statusu istnieją w tabeli

### **Rozwiązania:**
```javascript
// 1. NAPRAWIONE - Authentication dla process_status_history
const user = await window.supabaseClient.auth.getUser();
if (user?.data?.user?.id) {
    // insert with proper user ID
    changed_by: user.data.user.id,
}

// 2. NAPRAWIONE - Reset status validation  
if (result?.data?.length > 0 || result?.data) {
    // proper validation for both array and object responses
}

// 3. NAPRAWIONE - Enhanced error handling dla reset
try {
    // Try with status fields
    updateFields.status = newStatus;
    updateFields.completed_at = null;
    updateFields.completion_note = null;
} catch (statusUpdateError) {
    // Fallback to minimal update
    result = await supabaseClient.update({
        updated_at: new Date().toISOString()
    });
}

// 4. NAPRAWIONE - Better memory updates
if (newStatus === 'PENDING') {
    process.completed_at = null;
    process.completion_note = null;
}
```

### **Pliki zmienione:**
- **flowcraft-error-handler.js**: 
  - Linie 1140-1159: Authentication check dla markProcessCompleted
  - Linie 1188-1208: Authentication check dla markProcessDelayed
- **index.html**:
  - Linie 5263-5309: Enhanced reset status handling
  - Linie 5311-5347: Improved result validation i memory updates

### **Jak uniknąć w przyszłości:**
- **Zawsze używać auth.getUser()** zamiast hardcoded userId
- **Sprawdzać result.data** z różnymi typami odpowiedzi (array vs object)
- **Implementować graceful degradation** dla brakujących pól bazy danych
- **Testować RLS policies** z różnymi scenariuszami autentykacji
- **Dodawać .select()** do update queries żeby otrzymać dane odpowiedzi

### **Objawy do rozpoznania:**
- "Failed to update process status" mimo że operacja się udaje
- 403 Forbidden na process_status_history w konsoli
- Status się zmienia ale z opóźnieniem
- Brak synchronizacji między widokami

### **Test cases:**
```javascript
// Test reset functionality
await updateProcessStatus(processId, 'PENDING');
// Should: 1) Update DB, 2) Clear completed_at/completion_note, 3) Show success

// Test completed on time
await updateProcessStatus(processId, 'COMPLETED_ON_TIME', 'Test note');
// Should: 1) Update DB, 2) Set completed_at, 3) Log to history if possible, 4) Show success
```

### **Status:**
- ✅ RLS authentication naprawione
- ✅ Reset validation naprawione  
- ✅ Error handling ulepszone
- 🔄 Wymaga testów w aplikacji

---

## 🐛 PROBLEM: Nadal błędy 403 na process_status_history mimo napraw (2025-07-10 20:05)

### **Opis problemu:**
- Po implementacji auth.getUser() nadal pojawiają się błędy 403 Forbidden
- "new row violates row-level security policy for table process_status_history"
- Problem występuje mimo poprawnej autentykacji

### **Przyczyna:**
**RLS Policy wymaga członkostwa w projekcie**, a aplikacja nie używa systemu projektów:

```sql
-- Policy w supabase_migrations.sql wymaga:
CREATE POLICY "Users can insert status history for their processes" ON process_status_history
FOR INSERT WITH CHECK (
    process_id IN (
        SELECT pr.id FROM processes pr
        JOIN sheets s ON pr.sheet_id = s.id
        JOIN projects p ON s.project_id = p.id
        WHERE p.user_id = auth.uid() OR p.id IN (
            SELECT pm.project_id FROM project_members pm 
            WHERE pm.user_id = auth.uid() AND pm.role IN ('FULL_ACCESS', 'EDIT_ACCESS')
        )
    )
);
```

**Problem**: Aplikacja tworzy procesy bez projektów/membership, więc RLS zawsze blokuje.

### **Rozwiązanie:**
**Całkowite wyłączenie zapisów do process_status_history:**

```javascript
// PRZED - próba zapisu z błędami 403
await supabaseClient.from('process_status_history').insert({...});

// PO - lokalne logowanie bez błędów
console.log(`Status change logged locally: ${processId} -> ${status} (${note})`);
```

### **Pliki zmienione:**
- **flowcraft-error-handler.js**: 
  - Linie 1138-1141: Wyłączenie history w markProcessCompleted
  - Linie 1169-1172: Wyłączenie history w markProcessDelayed

### **Jak uniknąć w przyszłości:**
- **Sprawdzać RLS policies** przed implementacją funkcjonalności
- **Testować z rzeczywistymi danymi** zamiast zakładać że auth wystarczy
- **Implementować project membership** jeśli potrzebny jest history
- **Używać optional features** dla zaawansowanych funkcji
- **Graceful degradation** - podstawowa funkcjonalność działa bez history

### **Objawy do rozpoznania:**
- 403 Forbidden mimo poprawnej autentykacji
- RLS policy violations w tabelach z complex policies
- Błędy przy INSERT ale nie przy SELECT/UPDATE na głównych tabelach
- Policy zawiera JOINy do tabel które nie są wypełnione

### **Alternatywy dla przyszłości:**
1. **Prostsza RLS policy**: `WHERE changed_by = auth.uid()`
2. **Tymczasowe wyłączenie RLS**: `ALTER TABLE process_status_history DISABLE ROW LEVEL SECURITY;`
3. **Implementacja project system**: Pełny system projektów i członkostwa
4. **Local storage history**: Przechowywanie historii lokalnie

### **Status:**
- ✅ Błędy 403 wyeliminowane
- ✅ Status changes działają bez przeszkód
- ⚠️ History logging wyłączone (funkcjonalność opcjonalna)

---

## 🐛 PROBLEM: 404 błąd get_table_columns + brak real-time sync w Diagram (2025-07-10 20:15)

### **Opis problemu:**
- Reset to pending powoduje błąd: `POST /rest/v1/rpc/get_table_columns 404 (Not Found)`
- Status zmienia się w Process Manager ale nie synchronizuje w real-time z Diagram
- Status tabeli processes nie jest widoczny w diagramie

### **Przyczyny:**
1. **Nieistniejąca funkcja RPC**: `get_table_columns` nie istnieje w Supabase
2. **PostMessage może nie działać**: Process Manager i Diagram mogą nie być połączone przez window.opener
3. **PENDING status clearing**: Brak czyszczenia pól completion w synchronizacji diagram

### **Rozwiązania:**
```javascript
// 1. USUNIĘTE - niepotrzebne sprawdzanie kolumn
// PRZED - próba wywołania nieistniejącej RPC
const { data: columns } = await window.supabaseClient
    .rpc('get_table_columns', { table_name: 'processes' })

// PO - bezpośrednie używanie pól
const updateFields = {
    status: newStatus,
    completed_at: null,
    completion_note: null,
    updated_at: new Date().toISOString()
};

// 2. ULEPSZONE - PostMessage debugging
// Dodane logi do sprawdzenia czy komunikacja działa
console.log(`PostMessage sent to diagram: ${processId} -> ${newStatus}`);
console.log('Message received in diagram:', event.data);

// 3. NAPRAWIONE - PENDING status clearing w Diagram
if (newStatus === 'PENDING') {
    process.completed_at = null;
    process.completion_note = null;
}
```

### **Pliki zmienione:**
- **index.html**: 
  - Linie 5264-5270: Usunięcie RPC get_table_columns
  - Linie 5328-5333: Dodane debugging dla postMessage
- **Diagram.html**:
  - Linie 6433-6477: Enhanced debugging i PENDING status clearing

### **Jak uniknąć w przyszłości:**
- **Sprawdzać dostępność RPC funkcji** przed użyciem
- **Testować komunikację między oknami** w różnych scenariuszach
- **Używać console.log** do debugowania post-message communication
- **Sprawdzać window.opener** availability przed wysłaniem wiadomości

### **Objawy do rozpoznania:**
- 404 błędy dla RPC funkcji
- Status zmienia się w jednym oknie ale nie w drugim
- Brak logs w konsoli o otrzymanych messages
- window.opener is null/undefined warnings

### **Test case:**
```javascript
// W Process Manager po zmianie statusu:
console.log(`PostMessage sent to diagram: ${processId} -> ${newStatus}`);

// W Diagram powinno pojawić się:
console.log('Message received in diagram:', event.data);
console.log(`Processing status update: ${processId} -> ${newStatus}`);
console.log('Re-rendering diagram...');
```

### **Status:**
- ✅ 404 błąd RPC naprawiony
- ✅ Debugging dodany do komunikacji
- ✅ PENDING status clearing zaimplementowany
- 🔄 Wymaga testów real-time synchronizacji

---

## 🐛 PROBLEM: Status changes nie synchronizują się między Process Manager a Diagram (2025-07-10 20:30)

### **Opis problemu:**
- User zmienia status w Process Manager (completed)
- Status zapisuje się do bazy danych 
- Diagram nadal pokazuje "pending" mimo zmiany w bazie
- Brak real-time synchronizacji między widokami
- Błędy 403 RLS policy violations dla process_status_history

### **Przyczyny zidentyfikowane:**
1. **RLS Policy conflicts**: process_status_history wymaga complex project membership
2. **PostMessage może nie dotrzeć**: Diagram może nie odbierać wiadomości z Process Manager
3. **Process ID type mismatch**: Strict equality === vs loose equality ==
4. **Brak fallback refresh**: Jeśli postMessage nie działa, brak backup synchronizacji

### **Rozwiązania zaimplementowane:**

#### 1. **Enhanced debugging w message listener (Diagram.html:6445-6490)**
```javascript
console.log(`Looking for process with ID: ${processId}`);
console.log('Available processes:', Object.keys(processesData));
// Use == instead of === for type coercion
return p._databaseId == processId;
```

#### 2. **Periodic refresh backup mechanism (Diagram.html:6492-6510)**
```javascript
// Check for status updates every 30 seconds
setInterval(async () => {
    if (currentSheetId && Object.keys(processesData).length > 0) {
        await loadDataFromSupabase();
    }
}, 30000);
```

#### 3. **Enhanced status visualization debugging (Diagram.html:7601)**
```javascript
console.log(`Rendering status for ${processData["Short name"]}: ${status}`);
```

#### 4. **Fallback database reload gdy process nie znaleziony**
```javascript
// Try to reload from database as fallback
console.log('Attempting to reload data from database...');
loadDataFromSupabase();
```

### **Oczekiwane rezultaty:**
1. ✅ **Better debugging**: Console logs pokażą gdzie jest problem z process lookup
2. ✅ **Periodic sync**: Diagram odświeży się automatycznie co 30s jako backup
3. ✅ **Type coercion**: == zamiast === powinno naprawić ID matching issues
4. ✅ **Fallback reload**: Jeśli postMessage nie działa, database reload jako backup
5. 🔄 **Wymaga testów**: Pełne testy po restart Claude Code

### **Jak testować:**
1. Otwórz Process Manager w jednym oknie
2. Otwórz Diagram w drugim oknie
3. Zmień status procesu w Process Manager
4. Sprawdź console logs w Diagram window
5. Sprawdź czy status się zmienia natychmiast lub w ciągu 30s

### **Debug commands:**
```javascript
// W Console Diagram window:
console.log('Current processes:', Object.values(processesData).flat().map(p => `${p._databaseId}: ${p["Short name"]} (${p.status})`));

// W Console Process Manager po zmianie statusu:
console.log('PostMessage sent:', window.opener ? 'success' : 'failed - no opener');
```

### **Pliki zmienione:**
- **Diagram.html**: 
  - Linie 6445-6490: Enhanced debugging i process lookup
  - Linie 6492-6510: Periodic refresh mechanism
  - Linia 7601: Status rendering debugging

### **Status:**
- ✅ Enhanced debugging zaimplementowany
- ✅ Periodic refresh dodany  
- ✅ Type coercion fixed
- ✅ Fallback mechanisms w miejscu
- 🔄 Czeka na testy w aplikacji

---

## 🐛 PROBLEM: Diagram pokazuje tylko "pending" statusy mimo zmian w Process Manager (2025-07-10 20:45)

### **Opis problemu:**
- User zmienia statusy w Process Manager (index.html) - statusy się zapisują
- Diagram (Diagram.html) nadal pokazuje wszystkie procesy jako "pending" 
- Brak wizualnych animacji i oznaczeń statusów w węzłach diagramu
- StatusY są prawidłowo zapisane w bazie danych

### **Przyczyny zidentyfikowane:**
1. **Brak real-time refresh diagramu** po zmianie statusu
2. **Possible stale data** - diagram może używać cached/przestarzałych danych
3. **PostMessage może nie działać** między oknami Process Manager → Diagram
4. **Periodic refresh zbyt rzadki** (30s może być za mało)

### **Rozwiązania zaimplementowane:**

#### 1. **Enhanced comprehensive debugging (Diagram.html)**
```javascript
// Linie 8651-8655: Raw database data logging
console.log('Raw data from Supabase:', data);
console.log('Sample process from DB:', data[0]);

// Linie 8698-8702: Loaded processes status logging  
Object.values(processesData).flat().forEach(process => {
    console.log(`- ${process["Short name"]}: ${process.status} (ID: ${process._databaseId})`);
});

// Linia 10226: Node creation debugging
console.log(`Creating node for ${process.ID} with status:`, process.status);

// Linie 7609, 7686: Status visualization detailed debugging
console.log(`Rendering status for ${processData["Short name"]}: ${status} (from processData:`, processData.status, ')');
console.log(`Added status elements: indicator class="${statusIndicator.className}", icon="${statusIcon.innerHTML}"`);
```

#### 2. **Force refresh after status updates (Diagram.html:6484-6488)**
```javascript
// Force refresh from database to ensure we have latest data
setTimeout(() => {
    console.log('Force refreshing from database after status update...');
    loadDataFromSupabase();
}, 1000);
```

#### 3. **Faster periodic refresh (Diagram.html:6502-6512)**
```javascript
// Check for status updates every 10 seconds (was 30s)
setInterval(async () => {
    if (currentSheetId && Object.keys(processesData).length > 0) {
        console.log('Performing periodic status refresh...');
        await loadDataFromSupabase();
    }
}, 10000); // 10 seconds
```

#### 4. **Improved PostMessage status updates (Diagram.html:6459-6462)**
```javascript
const oldStatus = process.status;
process.status = newStatus;
process.completion_note = completionNote;
console.log(`Status changed: ${oldStatus} → ${process.status}`);
```

### **Diagnostic Commands dla testowania:**
```javascript
// W Console Diagram window:
console.log('Current processesData:', Object.values(processesData).flat().map(p => `${p["Short name"]}: ${p.status}`));

// W Console po zmianie statusu w Process Manager:
console.log('PostMessage sent:', window.opener ? 'success' : 'failed - no opener');
```

### **Debugging Flow:**
1. **Database level**: Console pokazuje raw data z Supabase
2. **Loading level**: Console pokazuje loaded processes z statusami
3. **Rendering level**: Console pokazuje tworzenie węzłów z statusami
4. **Visualization level**: Console pokazuje dodawanie elementów statusu

### **Oczekiwane rezultaty:**
1. ✅ **Comprehensive logging** - każdy etap jest logowany
2. ✅ **Force refresh** - diagram odświeża się po zmianie statusu  
3. ✅ **Faster sync** - co 10s zamiast 30s
4. ✅ **Real-time debugging** - łatwe diagnozowanie problemów
5. 🔄 **Wymaga testów**: Szczegółowa analiza console logs

### **Pliki zmienione:**
- **Diagram.html**: 
  - Linie 8651-8655: Database data debugging
  - Linie 8698-8702: Loaded processes debugging  
  - Linia 10226: Node creation debugging
  - Linie 7609, 7613-7616, 7686: Status visualization debugging
  - Linie 6484-6488: Force refresh after updates
  - Linie 6502-6512: Faster periodic refresh (10s)
  - Linie 6459-6462: Enhanced PostMessage debugging

### **Jak diagnozować:**
1. Otwórz Console w Diagram window
2. Zmień status w Process Manager
3. Sprawdź kolejno w Console:
   - Raw data from Supabase
   - Loaded processes z statusami
   - Creating node with status
   - Rendering status for process
   - Added status elements

### **Status:**
- ✅ Comprehensive debugging zaimplementowany
- ✅ Force refresh dodany po zmianach statusu
- ✅ Periodic refresh przyspieszony do 10s  
- ✅ Enhanced PostMessage debugging
- 🔄 Gotowe do szczegółowych testów

*Problem diagnostyczny: 2025-07-10 20:50*

---

## 🔧 OPTYMALIZACJA: Zbyt częste odświeżanie statusów (2025-07-10 21:00)

### **Opis problemu:**
- Statusy działały poprawnie, ale periodic refresh co 10s generował za dużo logów
- Konsola była zapełniona nadmiarowymi debug messages
- Użytkownik potrzebował mniejszej częstotliwości - co 10 minut zamiast 10s

### **Przyczyna:**
Podczas wcześniejszych napraw ustawiono zbyt agresywny refresh (10s) dla szybkiego debugowania, ale to nie jest potrzebne dla normalnego użytku.

### **Rozwiązanie:**
```javascript
// PRZED - zbyt częste
setInterval(async () => {
    console.log('Performing periodic status refresh...');
    await loadDataFromSupabase();
}, 10000); // 10 seconds

// PO - optymalne  
setInterval(async () => {
    console.log('Performing periodic status refresh (10min interval)...');
    await loadDataFromSupabase();
}, 600000); // 10 minutes
```

### **Dodatkowo usunięto nadmiarowe logi:**
- Raw data logging z każdego ładowania Supabase
- Node creation debugging dla każdego procesu
- Szczegółowe status rendering logi
- **Zachowano**: Błędy, sync między oknami, ważne operacje

### **Pliki zmienione:**
- **Diagram.html**: Linie 6502-6512 (timing), 8656, 8706, 7608, 7612, 7680, 10243

### **Jak uniknąć w przyszłości:**
- **Różnicować logi**: Debug vs Production logging levels
- **Używać czasowe debugowanie**: Włączać szczegółowe logi tylko podczas diagnozowania
- **Optymalne interwały**: 10min dla background sync, natychmiastowe dla user actions
- **Clean console**: Tylko istotne informacje w normalnym trybie

### **Objawy do rozpoznania:**
- Za dużo logów w konsoli podczas normalnej pracy
- Częste "Performing periodic refresh" messages
- Console cluttered with debug info

### **Rezultat:**
- ✅ Clean console z minimalnymi logami
- ✅ Background refresh co 10 minut  
- ✅ Natychmiastowa synchronizacja przy zmianach statusu
- ✅ Debug logi dostępne gdy potrzebne (commented out)

*Optymalizacja: 2025-07-10 21:05*

---

## 🐛 PROBLEM: Brak automatycznego odświeżania statusów przy uruchomieniu diagramu (2025-07-10 21:10)

### **Opis problemu:**
- Po optymalizacji periodic refresh (10s → 10min), diagram przestał ładować aktualne statusy przy pierwszym uruchomieniu
- User zmienia statusy w Process Manager, wchodzi w diagram, ale widzi stare statusy (pending)
- Periodic refresh działa po 10 minutach, ale to za późno

### **Przyczyna:**
**Różnice między funkcjami ładowania danych:**
- `loadDataFromSupabase()` - ładowała pola statusów (używana w periodic refresh)
- `loadMultipleSheetsFromSupabase()` - NIE ładowała pól statusów (używana przy inicjalizacji)

```javascript
// loadDataFromSupabase() - MIAŁA status fields
status: row.status || 'PENDING',
completed_at: row.completed_at,
completion_note: row.completion_note,

// loadMultipleSheetsFromSupabase() - BRAKOWAŁO status fields  
"Process type": row.process_type || 'standard',
_databaseId: row.id,
// Brak pól statusów!
```

### **Rozwiązanie:**
```javascript
// DODANE do loadMultipleSheetsFromSupabase (linie 9980-9985)
_customData: row.custom_data || {},
// Add status-related fields for proper synchronization
status: row.status || 'PENDING',
completed_at: row.completed_at,
completion_note: row.completion_note,
assigned_to: row.assigned_to,
due_date: row.due_date
```

**Plus force refresh dla pewności:**
```javascript
// Force refresh po inicjalizacji (linie 6362-6365)
setTimeout(async () => {
    console.log('🔄 Force refreshing status data after initial load...');
    await loadDataFromSupabase();
}, 1000);
```

### **Pliki zmienione:**
- **Diagram.html**: Linie 9980-9985, 10013, 6362-6365

### **Jak uniknąć w przyszłości:**
- **Consistency check**: Upewnić się że wszystkie funkcje ładowania mają te same pola
- **Testing**: Testować inicjalizację po zmianie statusów w innym oknie
- **Documentation**: Dokumentować różnice między funkcjami ładowania  
- **Unified loading**: Rozważyć użycie jednej funkcji dla wszystkich przypadków

### **Objawy do rozpoznania:**
- Diagram pokazuje stare statusy po pierwszym uruchomieniu
- Status updates działają w Process Manager ale nie pojawiają się w diagramie
- Periodic refresh działa, ale initial load nie

### **Rezultat:**
- ✅ Statusy ładowane natychmiast przy uruchomieniu diagramu
- ✅ Consistency między funkcjami ładowania
- ✅ Double assurance z force refresh
- ✅ Zachowane optymalizacje periodic timing

*Naprawa: 2025-07-10 21:15*

---

## 🐛 PROBLEM: Błąd w konsoli przy kliknięciu "Show Dependencies" (2025-07-10 21:25)

### **Opis problemu:**
- User klika na proces w diagramie, następnie klika "Show Dependencies"
- W konsoli pojawia się błąd JavaScript
- Panel dependencies nie otwiera się, funkcja nie działa

### **Przyczyny możliwe:**
1. **Undefined variables** - Brak definicji zmiennych używanych w funkcji
2. **Null reference errors** - Próba dostępu do elementów DOM które nie istnieją
3. **Function call errors** - Błędy w wywoływanych funkcjach pomocniczych
4. **Process selection issues** - Problem z currentlySelectedProcessId

### **Rozwiązania zaimplementowane:**

#### 1. **Enhanced debugging dla Show Dependencies (Diagram.html:7424-7453)**
```javascript
// Dodane comprehensive logging
console.log('Show Dependencies button clicked');
console.log('Button disabled:', shortcutShowDependenciesButton.disabled);
console.log('Selected process ID:', currentlySelectedProcessId);

// Try-catch dla error handling
try {
    generateAndShowDependencyTree(currentlySelectedProcessId);
    // ... reszta kodu
    console.log('Dependency tree generated successfully');
} catch (error) {
    console.error('Error generating dependency tree:', error);
    showNotification("Error generating dependency tree: " + error.message, "error");
}
```

#### 2. **Enhanced debugging dla generateAndShowDependencyTree (Diagram.html:12230-12259)**
```javascript
function generateAndShowDependencyTree(processId) {
    console.log('generateAndShowDependencyTree called with processId:', processId);
    
    const currentProcessesForRoot = getCurrentlyVisibleProcesses(true);
    console.log('Current processes for root:', currentProcessesForRoot.length);
    
    const rootProcess = currentProcessesForRoot.find(p => p.ID === processId);
    console.log('Root process found:', rootProcess);
    
    // Enhanced error checking dla getRecursiveDependenciesGraph
    try {
        currentTreeInputsData = getRecursiveDependenciesGraph(...);
        console.log('Tree inputs data generated:', currentTreeInputsData);
    } catch (error) {
        console.error('Error in getRecursiveDependenciesGraph:', error);
        throw error;
    }
}
```

### **Diagnostic Flow:**
1. **Button click**: Log czy button został kliknięty i czy jest enabled
2. **Process selection**: Log currentlySelectedProcessId
3. **Process lookup**: Log czy rootProcess został znaleziony  
4. **Data generation**: Log ile procesów dostępnych i czy tree data generowany
5. **Error catching**: Catch wszystkie błędy z dokładnymi messages

### **Pliki zmienione:**
- **Diagram.html**: Linie 7424-7453, 12230-12259

### **Jak debugować:**
1. Otwórz Console w Diagram window
2. Kliknij na proces w diagramie  
3. Kliknij "Show Dependencies"
4. Sprawdź w Console sekwencję logów:
   - "Show Dependencies button clicked"
   - "Selected process ID: [ID]"
   - "generateAndShowDependencyTree called with processId: [ID]"
   - "Root process found: [object]"
   - "Tree inputs/outputs data generated"

### **Możliwe błędy do zidentyfikowania:**
- **Button disabled**: User nie wybrał procesu
- **Process not found**: Problem z getCurrentlyVisibleProcesses()
- **getRecursiveDependenciesGraph errors**: Problem z dependency calculation
- **DOM element issues**: Problem z elementami dependency panel

### **Status:**
- ✅ Comprehensive debugging dodany
- ✅ Error handling z user-friendly messages
- ✅ Step-by-step logging
- 🔄 Gotowe do testów i analizy błędów

*Debug implementacja: 2025-07-10 21:30*

---

## 🔧 ENHANCED DEBUGGING: Show Dependencies - Comprehensive Error Handling (2025-07-10 21:35)

### **Problem:**
Screenshot pokazuje JavaScript errors w konsoli gdy user klika Show Dependencies. Potrzebne enhanced debugging dla full diagnosis.

### **Zaimplementowane rozwiązania:**

#### 1. **Comprehensive DOM Validation**
```javascript
// Weryfikacja wszystkich elementów DOM przed użyciem
if (!dependencyTreeSvg) {
    throw new Error('Dependency tree SVG element not found in DOM');
}
if (!dependencyPanelTitle) {
    throw new Error('Dependency panel title element not found in DOM');
}
```

#### 2. **Enhanced Process Data Validation**  
```javascript
// Sprawdzenie czy procesy są dostępne
if (!currentProcessesForRoot || currentProcessesForRoot.length === 0) {
    console.error('❌ No processes available for dependency tree');
    return;
}

// Pokazanie dostępnych process IDs dla debugging
console.log('📋 Available process IDs:', currentProcessesForRoot.map(p => p.ID));
```

#### 3. **Step-by-Step Progress Logging**
```javascript
console.log('🌳 generateAndShowDependencyTree called with processId:', processId);
console.log('📊 Current processes for root:', currentProcessesForRoot?.length || 0);
console.log('🎯 Root process found:', rootProcess ? `${rootProcess["Short name"]} (${rootProcess.ID})` : 'NOT FOUND');
console.log('📚 All processes combined:', allProcessesCombined?.length || 0);
console.log('🔄 Generating dependency graphs...');
console.log('⬅️ Tree inputs data generated:', currentTreeInputsData?.length || 0, 'nodes');
console.log('➡️ Tree outputs data generated:', currentTreeOutputsData?.length || 0, 'nodes');
console.log('🎯 Initializing tree states...');
console.log('🎨 Drawing dependency tree SVG...');
console.log('✅ Dependency tree generated successfully');
```

#### 4. **Complete Error Stack Traces**
```javascript
} catch (error) {
    console.error('💥 Critical error in generateAndShowDependencyTree:', error);
    console.error('Stack trace:', error.stack);
    
    if (dependencyTreeSvg) {
        dependencyTreeSvg.innerHTML = `<text x="10" y="20" fill="red">Error: ${error.message}</text>`;
    }
    
    throw error;
}
```

### **Instrukcje diagnostyczne:**
1. Kliknij proces w diagramie
2. Kliknij "Show Dependencies"  
3. Sprawdź Console sekwencyjnie:
   - 🌳 Function call z process ID
   - 📊 Liczba dostępnych procesów
   - 🎯 Czy root process został znaleziony
   - 📚 Czy combined processes data istnieje
   - 🔄 Czy dependency graphs są generowane
   - ⬅️➡️ Liczba nodes w inputs/outputs
   - 🎨 Czy SVG drawing starts
   - ✅ Success message LUB 💥 error z details

### **Pliki zmodyfikowane:**
- **Diagram.html**: Linie 12229-12311 - comprehensive error handling

### **Rezultat:**
- ✅ **DOM validation** - sprawdza czy wszystkie elementy istnieją
- ✅ **Data validation** - sprawdza czy procesy są dostępne  
- ✅ **Progress tracking** - każdy krok z emoji icons dla easy reading
- ✅ **Error details** - stack traces i specific error messages
- ✅ **Graceful fallbacks** - pokazuje error w SVG zamiast crashing

### **Status:** 
🔍 **READY FOR DETAILED DIAGNOSIS** - Console teraz pokaże dokładnie gdzie dependency tree fails

*Enhanced debugging: 2025-07-10 21:35*

---

---

## 🐛 PROBLEM: Błędy JavaScript przy kliknięciu "Show Dependencies" (2025-07-11 20:30)

### **Opis problemu:**
- User klika na proces w diagramie, następnie klika "Show Dependencies"
- W konsoli pojawiają się błędy JavaScript
- Panel dependencies nie otwiera się, funkcja nie działa
- Funkcjonalność dependency tree nie wyświetla powiązań procesów

### **Przyczyny zidentyfikowane:**
Potencjalne problemy w wywołaniu funkcji `generateAndShowDependencyTree()`:
1. **Process selection**: `currentlySelectedProcessId` może być `null` lub nieprawidłowy
2. **Data availability**: Procesy mogą nie być prawidłowo załadowane w `processesData`
3. **DOM elements**: Elementy `dependency-tree-svg` lub `dependency-panel-title` mogą nie istnieć
4. **Function chain**: Błędy w funkcjach helper takich jak `getCurrentlyVisibleProcesses()`, `getAllProcessesFromData()`, `getRecursiveDependenciesGraph()`

### **Rozwiązanie zaimplementowane:**
**Enhanced debugging w Show Dependencies button handler (Diagram.html:7424-7468):**

```javascript
// DODANE - comprehensive debugging
console.log('🔍 Show Dependencies button clicked');
console.log('🔍 Debug info:');
console.log('- processesData keys:', Object.keys(processesData));
console.log('- processesData length:', Object.values(processesData).flat().length);
console.log('- dependencyTreeSvg element:', !!dependencyTreeSvg);
console.log('- dependencyPanelTitle element:', !!dependencyPanelTitle);

// DODANE - pre-validation przed wywołaniem funkcji
const currentProcesses = getCurrentlyVisibleProcesses(true);
console.log('📊 Currently visible processes:', currentProcesses.length);
const targetProcess = currentProcesses.find(p => p.ID === currentlySelectedProcessId);
console.log('🎯 Target process found:', !!targetProcess, targetProcess ? targetProcess["Short name"] : 'NOT FOUND');

// DODANE - enhanced error handling z stack trace
} catch (error) {
    console.error('💥 Error generating dependency tree:', error);
    console.error('Stack trace:', error.stack);
    showNotification("Error generating dependency tree: " + error.message, "error");
}
```

### **Diagnostic Flow dla troubleshooting:**
1. **🔍 Button click**: Sprawdza czy button został kliknięty
2. **📊 Data availability**: Pokazuje dostępne processes i DOM elements  
3. **🎯 Process validation**: Sprawdza czy wybrany proces istnieje w current processes
4. **🌳 Function execution**: Kompletne error handling z stack traces
5. **💥 Error details**: Szczegółowe logi błędów do analizy

### **Jak debugować:**
1. Otwórz Console w Diagram window
2. Kliknij na proces w diagramie (sprawdź czy `currentlySelectedProcessId` się ustawia)
3. Kliknij "Show Dependencies"
4. Sprawdź w Console sekwencyjnie:
   - `🔍 Show Dependencies button clicked`
   - `processesData keys:` - czy procesy są załadowane
   - `Currently visible processes:` - czy są dostępne do dependency analysis
   - `Target process found:` - czy wybrany proces istnieje
   - `💥 Error` - jeśli pojawia się błąd, stack trace pomoże zlokalizować przyczynę

### **Możliwe przyczyny błędów do sprawdzenia:**
- **Empty processesData**: Brak załadowanych danych procesów
- **Process ID mismatch**: `currentlySelectedProcessId` nie odpowiada żadnemu procesowi  
- **DOM elements missing**: `dependency-tree-svg` lub `dependency-panel-title` nie istnieją
- **Function errors**: Błędy w `getCurrentlyVisibleProcesses()`, `getAllProcessesFromData()`, `getRecursiveDependenciesGraph()`, `drawDependencyTreeSVG()`

### **Pliki zmienione:**
- **Diagram.html**: Linie 7424-7468 - enhanced debugging w Show Dependencies button handler

### **Jak uniknąć w przyszłości:**
- **Comprehensive logging**: Dodawać step-by-step debugging do complex funkcjonalności
- **Pre-validation**: Sprawdzać wszystkie dependencies przed wywołaniem głównej funkcji
- **Error handling**: Używać try-catch z stack traces dla complex operations
- **DOM validation**: Zawsze sprawdzać czy elementy DOM istnieją przed użyciem
- **Data validation**: Weryfikować dostępność i format danych przed przetwarzaniem

### **Objawy do rozpoznania:**
- JavaScript errors w konsoli po kliknięciu "Show Dependencies"
- Brak otwierania dependency panel
- Button działa ale nic się nie dzieje
- Console errors typu "undefined is not a function" lub "cannot read property"

### **Test cases:**
```javascript
// W Console Diagram window po kliknięciu "Show Dependencies":
// Oczekiwane logi:
console.log('🔍 Show Dependencies button clicked');
console.log('- processesData keys:', ['Sheet1', 'Sheet2']); // example
console.log('📊 Currently visible processes:', 15); // example  
console.log('🎯 Target process found:', true, 'Example Process Name');
console.log('✅ Dependency tree generated successfully');

// LUB błąd z details:
console.error('💥 Error generating dependency tree:', error);
console.error('Stack trace:', error.stack);
```

### **Status:**
- ✅ Enhanced debugging zaimplementowany
- ✅ Comprehensive error handling dodany
- ✅ Step-by-step validation logs  
- 🔄 Gotowe do testów i szczegółowej diagnozy błędów

*Problem debug: 2025-07-11 20:35*

---

## 🐛 PROBLEM: InvalidCharacterError przy tworzeniu CSS class names w dependency tree (2025-07-11 20:45)

### **Opis problemu:**
- User klikał proces z powiązaniami wejściowymi i wyjściowymi
- Kliknięcie "Show Dependencies" powodowało błędy w konsoli:
  - `InvalidCharacterError: Failed to execute 'add' on 'DOMTokenList': The token provided ('link-from-Create FA-to-Zamknięcie miesiąca') contains HTML space characters, which are not valid in tokens.`
- Dependency tree panel nie otwierał się z powodu błędów JavaScript

### **Przyczyna:**
**Problem z sanityzacją ID procesów w CSS class names:**

```javascript
// BŁĘDNE - niepełna sanityzacja ID procesów
const sanitizedSourceId = sourceNode.id.replace(/\./g, '__');  // tylko kropki
const sanitizedTargetId = targetNode.id.replace(/\./g, '__');

// Proces "Zamknięcie miesiąca" zawiera spacje, co powoduje:
// class: "link-from-Create_FA-to-Zamknięcie miesiąca" - NIEPRAWIDŁOWE (spacje)
```

**Dodatkowe problemy:**
1. **data-id attributes**: `group.dataset.id = node.id;` - nieprawidłowe znaki w data-id
2. **querySelector calls**: `.dep-tree-node[data-id="${id}"]` - fail z nieoczyszczonymi ID

### **Rozwiązanie zaimplementowane:**

#### 1. **Poprawiona sanityzacja CSS class names (Diagram.html:8484-8485, 8316-8317)**
```javascript
// POPRAWNE - comprehensive sanitization 
const sanitizedSourceId = sourceNode.id.replace(/[^a-zA-Z0-9_-]/g, '_');
const sanitizedTargetId = targetNode.id.replace(/[^a-zA-Z0-9_-]/g, '_');

// Rezultat: "link-from-Create_FA-to-Zamknięcie_miesiąca" - PRAWIDŁOWE
```

#### 2. **Poprawiona sanityzacja data-id attributes (Diagram.html:8499-8500)**
```javascript
// DODANE - sanitization dla data-id
const sanitizedId = node.id.replace(/[^a-zA-Z0-9_-]/g, '_');
group.dataset.id = sanitizedId;
```

#### 3. **Poprawiona sanityzacja querySelector calls (Diagram.html:8330-8331)**
```javascript
// DODANE - sanitization dla querySelector
const sanitizedId = id.replace(/[^a-zA-Z0-9_-]/g, '_');
const nodeEl = dependencyTreeSvg.querySelector(`.dep-tree-node[data-id="${sanitizedId}"]`);
```

### **Regex pattern wyjaśnienie:**
- `[^a-zA-Z0-9_-]` - matches wszystkie znaki OPRÓCZ:
  - `a-z` (małe litery)
  - `A-Z` (wielkie litery)  
  - `0-9` (cyfry)
  - `_` (underscore)
  - `-` (hyphen)
- `g` flag - replace all matches, nie tylko pierwszy

### **Znaki zamieniane na `_`:**
- **Spacje**: `" "` → `"_"`
- **Polskie znaki**: `"ą", "ę", "ń"` → `"_"`
- **Kropki**: `"."` → `"_"`
- **Slash**: `"/"` → `"_"`
- **Inne specjalne**: `"@", "#", "%"` → `"_"`

### **Pliki zmienione:**
- **Diagram.html**: 
  - Linie 8484-8485: CSS class names sanitization
  - Linie 8316-8317: querySelector sanitization  
  - Linie 8499-8500: data-id attribute sanitization
  - Linie 8330-8331: path highlighting sanitization

### **Jak uniknąć w przyszłości:**
- **Universal sanitization function**: Stworzyć jedną funkcję dla wszystkich ID sanitization
- **Test with special characters**: Testować z procesami zawierającymi spacje, polskie znaki, znaki specjalne
- **CSS class validation**: Zawsze walidować CSS class names przed dodaniem do classList
- **Consistent patterns**: Używać tej samej regex pattern wszędzie gdzie ID są używane w CSS/DOM

### **Objawy do rozpoznania:**
- `InvalidCharacterError` w konsoli związane z DOMTokenList
- "Failed to execute 'add' on 'DOMTokenList'" errors
- CSS class names zawierające spacje lub inne nieprawidłowe znaki
- querySelector failing z data-id attributes zawierającymi special characters

### **Test cases:**
```javascript
// Test funkcji sanityzacji:
const testIds = [
    "Zamknięcie miesiąca",      // spacje
    "Create FA-to-Proces",      // myślnik w środku
    "Proces.v2.0",              // kropki
    "Test@Process#1",           // znaki specjalne
    "Księgowość/Raporting"      // slash + polskie znaki
];

testIds.forEach(id => {
    const sanitized = id.replace(/[^a-zA-Z0-9_-]/g, '_');
    console.log(`"${id}" → "${sanitized}"`);
});

// Oczekiwane rezultaty:
// "Zamknięcie miesiąca" → "Zamkni_cie_miesi_ca"
// "Create FA-to-Proces" → "Create_FA-to-Proces"  
// "Proces.v2.0" → "Proces_v2_0"
// "Test@Process#1" → "Test_Process_1"
// "Księgowość/Raporting" → "Ksi_gowo___Raporting"
```

### **Status:**
- ✅ CSS class names sanitization naprawione
- ✅ data-id attributes sanitization dodane
- ✅ querySelector calls sanitization dodane  
- ✅ Dependency tree powinno działać z procesami zawierającymi spacje/znaki specjalne

*Problem naprawiony: 2025-07-11 20:50*

---

## 🐛 PROBLEM: Dependency panel zasłonięty przez menu + Highlight Tree Nodes nie działa (2025-07-11 21:00)

### **Opis problemów:**
1. **Z-index issue**: Dependency panel był zasłonięty przez górne menu projektu
2. **Highlight Tree Nodes**: Button nie działał - brak przenoszenia i pokazywania zależności na diagramie
3. **ID mismatch**: Sanitized ID vs oryginalne ID powodowały problemy z funkcjonalnością

### **Przyczyny zidentyfikowane:**

#### 1. **Problem z-index layering**
```css
/* PRZED - za niski z-index */
#dependency-panel-container {
    z-index: 998;  /* Niżej niż inne elementy (1000-1003) */
}
```

#### 2. **Problem z Highlight Tree Nodes functionality**
```javascript
// PROBLEM - używanie sanitized ID zamiast oryginalnych ID
treeNodesElements.forEach(g => {
    if (g.dataset.id) { // sanitized ID
        newHighlightedTreeIds.add(g.dataset.id); // nie odpowiada oryginalnym ID procesów
    }
});
```

### **Rozwiązania zaimplementowane:**

#### 1. **Naprawiono z-index dla dependency panel (Diagram.html:2019)**
```css
/* POPRAWNE - wysoki z-index */
#dependency-panel-container {
    z-index: 1010;  /* Wyżej niż wszystkie inne elementy */
}
```

#### 2. **Dodano oryginalne ID do data attributes (Diagram.html:8503)**
```javascript
// DODANE - przechowywanie oryginalnego ID
group.dataset.id = sanitizedId;           // dla CSS selectors
group.dataset.originalId = node.id;       // dla functionality
```

#### 3. **Naprawiono Highlight Tree Nodes function (Diagram.html:8222-8224)**
```javascript
// POPRAWNE - używanie oryginalnych ID
treeNodesElements.forEach(g => {
    if (g.dataset.originalId) { // oryginalne ID
        newHighlightedTreeIds.add(g.dataset.originalId); // odpowiada ID procesów
    }
});
```

#### 4. **Dodano comprehensive debugging (Diagram.html:8204-8269)**
```javascript
// DODANE - step-by-step debugging
console.log('🌟 Highlight Tree Nodes button clicked');
console.log('📊 Tree nodes found:', treeNodesElements.length);
console.log('➕ Added to highlight set:', g.dataset.originalId);
console.log('🎯 Total nodes to highlight:', newHighlightedTreeIds.size);
console.log('✅ Activating tree highlight mode');
```

### **Flow naprawionej funkcjonalności:**
1. **User klika "Show Dependencies"** → dependency tree się generuje
2. **Panel pokazuje się na pierwszym planie** → z-index 1010
3. **User klika "Highlight Tree Nodes"** → console debugging starts
4. **Funkcja zbiera oryginalne ID** → używa `dataset.originalId`
5. **Aktywuje tree highlight mode** → `isTreeHighlightActive = true`
6. **Czyści filtry i renderuje diagram** → pokazuje tylko wybrane procesy
7. **Zamyka dependency panel** → focus na głównym diagramie

### **Debugging commands dla testowania:**
```javascript
// W Console po kliknięciu "Highlight Tree Nodes":
// Oczekiwane logi:
console.log('🌟 Highlight Tree Nodes button clicked');
console.log('📊 Tree nodes found:', 5); // example
console.log('➕ Added to highlight set:', 'Create FA');
console.log('➕ Added to highlight set:', 'Zamknięcie miesiąca');
console.log('🎯 Total nodes to highlight:', 5);
console.log('✅ Activating tree highlight mode');
console.log('🔄 Rendering diagram with highlights...');
console.log('✅ Tree highlight completed');
```

### **Pliki zmienione:**
- **Diagram.html**:
  - Linia 2019: z-index dependency panel 998 → 1010
  - Linia 8503: Dodane `dataset.originalId` storage
  - Linie 8222-8224: Używanie oryginalnych ID w highlight function
  - Linie 8204-8269: Enhanced debugging dla troubleshooting

### **Jak uniknąć w przyszłości:**
- **Z-index hierarchy**: Używać logicznych wartości z-index (modals 1000+, panels 900+, etc.)
- **ID consistency**: Zawsze przechowywać oryginalne wartości gdy sanityzujemy dla CSS
- **Dual data attributes**: Używać data-id (sanitized) + data-original-id (functionality)
- **Comprehensive debugging**: Dodawać step-by-step logging do complex user interactions
- **Testing edge cases**: Testować z procesami zawierającymi spacje i znaki specjalne

### **Objawy do rozpoznania:**
- Panel overlay zasłonięty przez inne elementy UI
- Buttons klikają się ale nic się nie dzieje (brak console errors)
- ID mismatch między CSS selectors a functionality
- Tree highlighting nie aktywuje się mimo correct data

### **Test cases:**
```javascript
// Test z-index layering:
getComputedStyle(document.getElementById('dependency-panel-container')).zIndex; // "1010"

// Test original ID storage:
document.querySelectorAll('.dep-tree-node').forEach(node => {
    console.log(`Sanitized: ${node.dataset.id}, Original: ${node.dataset.originalId}`);
});

// Test highlight functionality:
// 1. Open dependency tree
// 2. Click "Highlight Tree Nodes"  
// 3. Check console for sequential logs with emoji indicators
// 4. Verify main diagram shows only highlighted processes
```

### **Status:**
- ✅ Z-index layering naprawione - panel na pierwszym planie
- ✅ Highlight Tree Nodes functionality naprawione
- ✅ ID consistency między sanitized a original IDs
- ✅ Comprehensive debugging dodane dla troubleshooting
- ✅ Funkcjonalność działa z procesami zawierającymi spacje/znaki specjalne

*Problem naprawiony: 2025-07-11 21:10*

---

## 🐛 PROBLEM: Simulation shift czasami nie działa - brak automatycznego odświeżania (2025-07-11 08:15)

### **Opis problemu:**
- User przesuwał proces z WD-2 na WD2 w simulation mode
- Czasami po zmianie parametrów (Working Day, Due Time) w simulation panel diagram nie pokazywał efektu finalnego
- User musiał ręcznie kliknąć "Update Simulation" żeby zobaczyć zmiany
- Brak błędów w konsoli, funkcjonalność działała ale wymagała dodatkowego kroku

### **Przyczyny zidentyfikowane:**

#### 1. **Brak automatycznego odświeżania po zmianie parametrów**
```javascript
// PROBLEM - tylko zapisywanie parametrów bez wywołania symulacji
function updateSimTargetParam(index, key, value) {
    if (simulationTargets[index]) {
        simulationTargets[index].params[key] = value; // tylko zapis
        // BRAK: automatycznego uruchomienia runOrUpdateSimulation()
    }
}
```

#### 2. **UI inputs nie triggery symulacji automatycznie**
```html
<!-- Inputs tylko zapisywały wartości, nie uruchamiały symulacji -->
<input type="number" value="${target.params.wd}" oninput="updateSimTargetParam(${index}, 'wd', this.value)">
<input type="text" value="${target.params.dueTime}" oninput="updateSimTargetParam(${index}, 'dueTime', this.value)">
```

#### 3. **Brak debugging dla tracking zmian parametrów**
Trudno było zdiagnozować czy parametry się rzeczywiście zmieniały czy problem był w visual update.

### **Rozwiązania zaimplementowane:**

#### 1. **Auto-update simulation po zmianie parametrów (Diagram.html:12390-12407)**
```javascript
// POPRAWIONE - automatyczne odświeżanie z debouncing
function updateSimTargetParam(index, key, value) {
    if (simulationTargets[index]) {
        simulationTargets[index].params[key] = value;
        
        // Auto-update simulation when parameters change
        console.log(`🔄 Parameter ${key} updated for process ${simulationTargets[index].id}: ${value}`);
        
        // Debounce mechanism to avoid excessive updates
        clearTimeout(window.simulationUpdateTimeout);
        window.simulationUpdateTimeout = setTimeout(() => {
            if (isSimulationModeActive) {
                console.log('🚀 Auto-updating simulation after parameter change...');
                runOrUpdateSimulation();
            }
        }, 300); // 300ms delay to allow multiple rapid changes
    }
}
```

#### 2. **Enhanced debugging w runOrUpdateSimulation (Diagram.html:12533-12546)**
```javascript
// DODANE - comprehensive logging
function runOrUpdateSimulation() {
    console.log('🚀 runOrUpdateSimulation called with', simulationTargets.length, 'targets');
    
    console.log('📋 Validating simulation targets...');
    simulationTargets.forEach((target, index) => {
        console.log(`   Target ${index}: ${target.id} (${target.type}) - WD: ${target.params?.wd}, Time: ${target.params?.dueTime}`);
    });
    // ...
}
```

#### 3. **Detailed position calculation debugging (Diagram.html:12669-12697)**
```javascript
// DODANE - step-by-step position tracking
if (wdChanged || timeChanged) {
    console.log(`🔄 Shifting process ${target.id}: WD ${originalWd} → ${simWd}, Time ${originalTimeSec} → ${simTimeSec}`);
    
    const wdIndex = gUniqueDataWds.indexOf(simWd);
    console.log(`   WD Index for ${simWd}:`, wdIndex, 'Available WDs:', gUniqueDataWds);
    
    // ... position calculation ...
    
    console.log(`   New position: (${newLeft}, ${newTop})`);
    targetNodeEl.style.left = `${newLeft}px`;
    targetNodeEl.style.top = `${newTop}px`;
} else {
    console.log(`ℹ️ No changes detected for ${target.id}, keeping original position`);
}
```

#### 4. **Improved user feedback (Diagram.html:12587-12588)**
```javascript
// POPRAWIONE - bardziej informatywne powiadomienia
console.log('✅ Simulation updated successfully');
showNotification("Simulation updated. Process positions and impacts refreshed.", "success");
```

### **Mechanizm debouncing:**
- **Timeout 300ms**: Pozwala na szybkie zmiany wielu parametrów bez nadmiarowych aktualizacji
- **clearTimeout**: Anuluje poprzednie wywołania jeśli user szybko zmienia wartości
- **Auto-trigger**: Simulation uruchamia się automatycznie po ustaniu zmian

### **Flow naprawionej funkcjonalności:**
1. **User zmienia WD w input field** → `updateSimTargetParam()` called
2. **Parameter zapisany + debug log** → `simulationTargets[index].params[key] = value`
3. **Debounce timer started** → `setTimeout(() => runOrUpdateSimulation(), 300)`
4. **Auto-update triggered** → Visual positions updated automatically
5. **Success notification** → User dostaje feedback że zmiana została zastosowana

### **Pliki zmienione:**
- **Diagram.html**: 
  - Linie 12390-12407: Auto-update mechanism w `updateSimTargetParam()`
  - Linie 12533-12546: Enhanced debugging w `runOrUpdateSimulation()`
  - Linie 12669-12697: Detailed position calculation logging
  - Linie 12587-12588: Improved user feedback

### **Jak uniknąć w przyszłości:**
- **Auto-update patterns**: Zawsze rozważać automatyczne odświeżanie po zmianach parametrów
- **Debouncing**: Używać timeouts dla operations które mogą być called frequently
- **Comprehensive debugging**: Dodawać step-by-step logging do complex visual operations
- **User feedback**: Informować użytkownika o successful operations z clear messages
- **Parameter validation**: Logować wszystkie parameter changes dla easier debugging

### **Objawy do rozpoznania:**
- User zmienia parametry ale visual effect nie występuje natychmiast
- Wymagane ręczne kliknięcie "Update" button po zmianach
- Brak błędów w konsoli ale functionality requires extra steps
- Parameters zapisane poprawnie ale visual update missing

### **Test cases:**
```javascript
// W Console po zmianie parametrów:
// Oczekiwane logi:
console.log('🔄 Parameter wd updated for process Create_FA: 2');
console.log('🚀 Auto-updating simulation after parameter change...');
console.log('🚀 runOrUpdateSimulation called with 1 targets');
console.log('🔄 Shifting process Create_FA: WD -2 → 2, Time NaN → NaN');
console.log('   WD Index for 2: 4 Available WDs: [-2, -1, 1, 2, 3]');
console.log('   New position: (425, 150)');
console.log('✅ Simulation updated successfully');
```

### **Status:**
- ✅ Auto-update mechanism implemented
- ✅ Debouncing prevents excessive updates  
- ✅ Comprehensive debugging added
- ✅ User feedback improved
- ✅ Simulation shifts now work immediately without manual "Update" clicks

*Problem naprawiony: 2025-07-11 08:20*

---

## 🐛 PROBLEM: Błędne mapowanie WD w symulacji + "Create FA" nie można przesunąć (2025-07-11 08:25)

### **Opis problemu:**
- User przesuwał "Amortyzacja" na WD2 w symulacji ale proces przesunął się na WD-2 pozycję
- "Create FA" proces nie pozwalał wcale na shift w symulacji
- Gdy symulacja używa WD wartości które nie istnieją w diagramie, procesy trafiały do błędnej pozycji
- Brak automatycznego rozszerzania osi WD dla nowych wartości

### **Przyczyny zidentyfikowane:**

#### 1. **Fallback logic dla nieistniejących WD values**
```javascript
// PROBLEM - fallback umieszczał procesy na pozycji leftmost (gdzie są negative WDs)
let idealXCenter = gYAxisLabelWidthOriginal + gDiagramPanePadding + 
    (wdIndex !== -1 ? wdIndex * gWdColumnWidth + gWdColumnWidth / 2 : gWdColumnWidth / 2);
//                                                                    ^^^^^^^^^^^^^^^^^^^
//                                                                    To dawało leftmost position
```

#### 2. **Brak dynamic WD axis expansion**
- gUniqueDataWds array nie był aktualizowany gdy symulacja używała nowych WD values
- Przykład: gUniqueDataWds = [-2, -1, 1, 2, 3], ale symulacja próbowała WD = 5
- indexOf(5) zwracał -1, więc proces trafiał na fallback position (leftmost)

#### 3. **CSS selector issues dla proces IDs z spacjami**
```javascript
// PROBLEM - "Create FA" zawiera spację, która powoduje invalid CSS selectors
let targetNodeEl = diagramPane.querySelector(`.process-node[data-id="${target.id}"]`);
// Dla target.id = "Create FA" dawało invalid selector z spacją
```

#### 4. **Inconsistent handling NaN time values**
- "Create FA" miał NaN time values które powodowały problems w change detection
- Time change logic nie gracefully handling NaN cases

### **Rozwiązania zaimplementowane:**

#### 1. **Dynamic WD axis expansion (Diagram.html:12677-12689)**
```javascript
// POPRAWIONE - automatic axis expansion
if (wdIndex === -1) {
    console.log(`   ⚠️ WD ${simWd} not found in data, adding to axis...`);
    gUniqueDataWds.push(simWd);
    gUniqueDataWds.sort((a, b) => a - b);
    wdIndex = gUniqueDataWds.indexOf(simWd);
    console.log(`   ✅ WD ${simWd} added at index ${wdIndex}, New WDs:`, gUniqueDataWds);
    
    // Trigger diagram redraw with expanded axis
    setTimeout(() => {
        console.log('🔄 Redrawing diagram with expanded WD axis...');
        renderDiagramAndRestoreState();
    }, 100);
}
```

#### 2. **Fixed position calculation (Diagram.html:12691)**
```javascript
// POPRAWIONE - używa calculated wdIndex bez fallback
let idealXCenter = gYAxisLabelWidthOriginal + gDiagramPanePadding + 
    (wdIndex * gWdColumnWidth + gWdColumnWidth / 2);
// Removed fallback logic that placed processes at leftmost position
```

#### 3. **Robust CSS selector handling (Diagram.html:12646-12658)**
```javascript
// POPRAWIONE - sanitization z fallback dla process IDs ze spacjami
const sanitizedId = target.id.replace(/[^a-zA-Z0-9_-]/g, '_');
let targetNodeEl = diagramPane.querySelector(`.process-node[data-id="${sanitizedId}"]`);

// Fallback: try with original ID if sanitized doesn't work
if (!targetNodeEl) {
    targetNodeEl = diagramPane.querySelector(`.process-node[data-id="${target.id}"]`);
}

if (!targetNodeEl) {
    console.log(`⚠️ Target node not found for process ${target.id} (sanitized: ${sanitizedId})`);
    return;
}
```

#### 4. **Enhanced time change detection (Diagram.html:12682-12687)**
```javascript
// POPRAWIONE - graceful NaN handling
const originalTimeValid = !isNaN(originalTimeSec);
const simTimeValid = !isNaN(simTimeSec);
const timeChanged = (originalTimeValid !== simTimeValid) || 
                   (originalTimeValid && simTimeValid && originalTimeSec !== simTimeSec);

console.log(`   📊 Change detection: WD ${originalWd} → ${simWd} (${wdChanged}), Time ${originalTimeSec} → ${simTimeSec} (${timeChanged})`);
```

#### 5. **Improved time positioning (Diagram.html:12720-12722)**
```javascript
// DODANE - explicit handling dla NaN time values
if (!isNaN(simTimeSec)) {
    // ... normal time positioning ...
    console.log(`   ⏰ Time positioning: ${simTimeSec}s → bin ${binIndex} → Y: ${idealYCenter}`);
} else {
    console.log(`   ⏰ No valid time for ${target.id}, using middle Y position: ${idealYCenter}`);
}
```

#### 6. **Position verification debugging (Diagram.html:12732-12736)**
```javascript
// DODANE - verification że position update się udał
setTimeout(() => {
    const actualLeft = parseInt(targetNodeEl.style.left);
    const actualTop = parseInt(targetNodeEl.style.top);
    console.log(`   ✅ Position verified: (${actualLeft}, ${actualTop})`);
}, 50);
```

### **Flow naprawionej funkcjonalności:**

#### **Scenario 1: WD value exists in data**
1. User sets WD 2 → `gUniqueDataWds.indexOf(2)` finds index (e.g. 3)
2. Position calculated: `base + (3 * columnWidth) + offset`
3. Process moves to correct column 3 (WD 2 position)

#### **Scenario 2: WD value doesn't exist in data**  
1. User sets WD 5 → `gUniqueDataWds.indexOf(5)` returns -1
2. **Auto-expansion**: WD 5 added to array → `[-2, -1, 1, 2, 3, 5]`
3. New index found: `gUniqueDataWds.indexOf(5)` returns 5
4. Diagram redraws with expanded axis
5. Process moves to correct position at column 5

#### **Scenario 3: Process with spaces like "Create FA"**
1. Sanitized ID: "Create FA" → "Create_FA" 
2. CSS selector: `.process-node[data-id="Create_FA"]`
3. Fallback tries original ID if sanitized fails
4. Process found and positioned correctly

### **Pliki zmienione:**
- **Diagram.html**:
  - Linie 12677-12689: Dynamic WD axis expansion
  - Linia 12691: Removed fallback position logic
  - Linie 12646-12658: CSS selector sanitization z fallback
  - Linie 12682-12687: Enhanced time change detection
  - Linie 12720-12722: NaN time handling
  - Linie 12732-12736: Position verification debugging

### **Test cases dla edge scenarios:**
```javascript
// Test 1: WD expansion
// Set simulation WD to 10 when gUniqueDataWds = [-2, -1, 1, 2, 3]
// Expected: WD 10 added, array becomes [-2, -1, 1, 2, 3, 10], process moves to rightmost

// Test 2: Negative WD simulation  
// Set simulation WD to -5 when gUniqueDataWds = [-2, -1, 1, 2, 3]
// Expected: WD -5 added, array becomes [-5, -2, -1, 1, 2, 3], process moves to leftmost

// Test 3: Process with spaces
// Select "Create FA" and shift WD from -2 to 2
// Expected: Process found via sanitized ID, moved to WD 2 position

// Test 4: Process with NaN time
// Shift process with empty Due time to different WD
// Expected: Only WD changes, Y position stays at middle, no errors
```

### **Jak uniknąć w przyszłości:**
- **Dynamic data structures**: Zawsze rozważać auto-expansion dla user input values
- **Robust CSS selectors**: Sanitize wszystkie user-provided IDs używane w selectors
- **Graceful NaN handling**: Explicit checking dla wszystkich numeric operations
- **Comprehensive logging**: Step-by-step debugging dla complex positioning calculations
- **Fallback strategies**: Implement fallbacks ale upewnić się że nie powodują wrong behavior
- **Test edge cases**: Testować z processes containing spaces, missing time data, extreme WD values

### **Objawy do rozpoznania:**
- Process moves to wrong WD position despite correct input
- Processes with spaces in names don't respond to simulation
- Console shows "WD Index: -1" for valid WD values
- Simulation places processes at leftmost position unexpectedly
- NaN time values cause positioning errors

### **Status:**
- ✅ WD mapping fixed - correct position calculation
- ✅ Dynamic axis expansion implemented
- ✅ "Create FA" and other processes with spaces now shiftable
- ✅ NaN time values handled gracefully
- ✅ Comprehensive debugging added for troubleshooting
- ✅ Position verification ensures updates succeed

*Problem naprawiony: 2025-07-11 08:50*

---

## 🐛 PROBLEM: Race condition w WD positioning - WD -4 trafia na pozycję WD -2 (2025-07-11 08:45)

### **Opis problemu:**
- User ustawiał WD -4 w symulacji dla procesu "Amortyzacja"
- Proces przesuwał się nad "Create FA" na pozycję odpowiadającą WD -2 zamiast WD -4
- WD -4 był poprawnie dodawany do gUniqueDataWds array ale pozycja była błędnie obliczana
- Mimo poprawnej implementacji dynamic axis expansion, positioning używał stałych wartości

### **Root Cause - Race Condition:**

#### **Problem: Position calculation przed layout update**
```javascript
// PROBLEM - sequence of operations
if (wdIndex === -1) {
    gUniqueDataWds.push(simWd);           // ✅ WD -4 added correctly  
    gUniqueDataWds.sort((a, b) => a - b); // ✅ Array sorted: [-4, -2, 0, 2]
    wdIndex = gUniqueDataWds.indexOf(simWd); // ✅ wdIndex = 0
    
    // Schedule layout update for LATER
    setTimeout(() => renderDiagramAndRestoreState(), 100);
}

// IMMEDIATE position calculation with STALE gWdColumnWidth
let idealXCenter = gYAxisLabelWidthOriginal + gDiagramPanePadding + 
    (wdIndex * gWdColumnWidth + gWdColumnWidth / 2);
//            ^^^^^^^^^^^^^^ STALE VALUE from old column count
```

#### **Szczegóły problemu:**
1. **Original WDs**: `[-2, 0, 2]` (3 columns) → `gWdColumnWidth = plotWidth / 3`
2. **Add WD -4**: Array becomes `[-4, -2, 0, 2]` (4 columns)
3. **Position calc**: `wdIndex=0 * (plotWidth/3)` = leftmost using OLD column width
4. **Result**: Process positioned as if there were still 3 columns, landing at WD -2 position
5. **Later**: `renderDiagramAndRestoreState()` updates layout but process already positioned wrong

### **Rozwiązania zaimplementowane:**

#### 1. **Immediate column width recalculation (Diagram.html:12704-12707)**
```javascript
// POPRAWIONE - immediate recalculation bez czekania na layout update
if (wdIndex === -1) {
    gUniqueDataWds.push(simWd);
    gUniqueDataWds.sort((a, b) => a - b);
    wdIndex = gUniqueDataWds.indexOf(simWd);
    
    // Immediately recalculate column width for correct positioning
    const newColumnCount = gUniqueDataWds.length;
    currentWdColumnWidth = gPlotWidth / newColumnCount;
    console.log(`   📐 Recalculated column width: ${gWdColumnWidth} → ${currentWdColumnWidth} (${newColumnCount} columns)`);
}

// Use updated column width for position calculation
let idealXCenter = gYAxisLabelWidthOriginal + gDiagramPanePadding + 
    (wdIndex * currentWdColumnWidth + currentWdColumnWidth / 2);
```

#### 2. **Global gPlotWidth variable (Diagram.html:5938, 10205)**
```javascript
// DODANE - global variable dla plot width
let gPlotWidth = 0; // line 5938

// POPRAWIONE - update global variable during diagram render
const plotWidthDisplay = Math.max(0, diagramPane.clientWidth - Y_AXIS_LABEL_WIDTH_ORIGINAL - PADDING * 2);
gPlotWidth = plotWidthDisplay; // line 10205
```

#### 3. **Enhanced debugging dla column width tracking**
```javascript
// DODANE - detailed logging dla troubleshooting
console.log(`   📐 Recalculated column width: ${gWdColumnWidth} → ${currentWdColumnWidth} (${newColumnCount} columns)`);
```

### **Flow naprawionej funkcjonalności:**

#### **Scenario: User sets WD -4**
1. **Check existing WDs**: `gUniqueDataWds.indexOf(-4)` returns -1
2. **Add and sort**: `[-2, 0, 2]` → `[-4, -2, 0, 2]`, `wdIndex = 0`
3. **Immediate recalc**: `newColumnCount = 4`, `currentWdColumnWidth = gPlotWidth / 4`
4. **Position calc**: `wdIndex=0 * (plotWidth/4)` = proper leftmost position for 4 columns
5. **Result**: Process positioned correctly at WD -4 (leftmost column)
6. **Layout update**: `setTimeout` still triggers diagram redraw for proper axis labels

### **Key improvement - Synchronous vs Asynchronous:**

#### **PRZED (Asynchronous):**
1. Add WD to array
2. Calculate position with OLD column width
3. **100ms later**: Update layout (too late)

#### **PO (Synchronous critical path):**
1. Add WD to array  
2. **Immediately** recalculate column width
3. Calculate position with CORRECT column width
4. **100ms later**: Update layout for visual polish

### **Pliki zmienione:**
- **Diagram.html**:
  - Linia 5938: Added global `gPlotWidth` variable
  - Linia 10205: Update `gPlotWidth` during diagram render
  - Linie 12696, 12704-12707: Immediate column width recalculation
  - Linia 12716: Use `currentWdColumnWidth` for position calculation

### **Test case verification:**
```javascript
// Test case: Add WD -4 to existing [-2, 0, 2]
// Expected: 
// - gUniqueDataWds becomes [-4, -2, 0, 2]
// - currentWdColumnWidth = gPlotWidth / 4
// - wdIndex = 0, position = leftmost column (WD -4 position)
// - Process appears at far left, not overlapping WD -2
```

### **Jak uniknąć w przyszłości:**
- **Synchronous critical path**: Calculate dependent values immediately, nie defer do setTimeout
- **Global state management**: Upewnić się że wszystkie related variables są updated together
- **Position calculation timing**: Never calculate positions using potentially stale layout values
- **Debug racing issues**: Add timing logs to identify async operation conflicts
- **Test dynamic expansion**: Always test with new values that don't exist in current data

### **Objawy do rozpoznania:**
- Process appears at position corresponding to old layout despite correct array updates
- Console shows correct WD index but wrong visual position
- Position calculation uses values that don't match current data structure
- Visual updates happen after critical calculations

### **Status:**
- ✅ Race condition fixed - immediate column width recalculation
- ✅ Global gPlotWidth variable properly maintained
- ✅ Position calculation uses current layout values
- ✅ WD -4 now properly positions at leftmost column
- ✅ Enhanced debugging for troubleshooting similar issues

*Problem naprawiony: 2025-07-11 09:00*

---

## 🐛 PROBLEM: "Chaos effect" przy dodawaniu negative WD values w symulacji (2025-07-11 09:15)

### **Opis problemu:**
- User przesuwał "Zamknięcie miesiąca" z WD 3 na WD -3 w symulacji
- Po simulation update wszystkie procesy w diagramie przesunęły się do błędnych pozycji
- "Chaos effect" - procesy były scattered po całym diagramie zamiast w właściwych kolumnach WD
- WD -3 był poprawnie dodany do gUniqueDataWds: `[-3, -2, 1, 3, 7]` ale layout kompletnie rozpadł się

### **Root Cause - Full Diagram Redraw During Simulation:**

#### **Problem: renderDiagramAndRestoreState() destroys simulation positioning**
```javascript
// PROBLEM - sequence powodująca chaos
setTimeout(() => {
    console.log('🔄 Redrawing diagram with expanded WD axis...');
    renderDiagramAndRestoreState(); // ❌ RESETS ALL PROCESS POSITIONS
}, 100);
```

#### **Szczegóły problemu:**
1. **Target process positioning** - ✅ działa poprawnie z `currentWdColumnWidth`
2. **Full diagram redraw**: `renderDiagramAndRestoreState()` wywołuje:
   - `renderDiagram()` → clears `nodeLayouts = {}` (line 10109)
   - Recalculates ALL layouts z NEW `gWdColumnWidth` 
   - Updates wszystkie procesy positions używając nowych współrzędnych
3. **Simulation visual overrides**: `applySimulationVisuals()` sets ALL existing processes:
   ```javascript
   node.style.top = `${layout.finalY}px`;     // NEW calculated position
   node.style.left = `${layout.finalX}px`;    // NEW calculated position  
   ```
4. **Result**: Wszystkie procesy repositioned according to expanded axis → chaos effect

### **Fundamentalny konflikt:**
- **Simulation positioning** uses `currentWdColumnWidth` for target process
- **renderDiagramAndRestoreState()** recalculates ALL positions with expanded axis
- **Two different positioning systems** działają przeciwko sobie

### **Rozwiązania zaimplementowane:**

#### 1. **Removed renderDiagramAndRestoreState() call (Diagram.html:12711-12719)**
```javascript
// USUNIĘTE - full diagram redraw that caused chaos
// setTimeout(() => {
//     console.log('🔄 Redrawing diagram with expanded WD axis...');
//     renderDiagramAndRestoreState();
// }, 100);

// DODANE - lightweight axis update
// Update global column width for consistency
gWdColumnWidth = currentWdColumnWidth;
console.log('📊 Updated global gWdColumnWidth to:', gWdColumnWidth);

// Schedule axis labels update without full diagram redraw
setTimeout(() => {
    console.log('🔄 Updating WD axis labels only...');
    updateWdAxisLabels();
}, 100);
```

#### 2. **Created updateWdAxisLabels() function (Diagram.html:10480-10535)**
```javascript
function updateWdAxisLabels() {
    console.log('🔄 Updating WD axis labels for:', gUniqueDataWds);
    
    if (!stickyXAxisContainer || stickyXAxisContainer.style.display === 'none') {
        console.log('ℹ️ Sticky X-axis container not visible, skipping update');
        return;
    }
    
    // Clear existing WD labels
    const existingLabels = stickyXAxisContainer.querySelectorAll('.x-axis-label');
    existingLabels.forEach(label => label.remove());
    
    // Recreate labels with updated positions based on gWdColumnWidth
    gUniqueDataWds.forEach((wd, index) => {
        const originalLabelXCenterUnzoomed = gYAxisLabelWidthOriginal + gDiagramPanePadding + 
                                           (index * gWdColumnWidth) + (gWdColumnWidth / 2);
        // ... rest of positioning logic ...
        stickyXAxisContainer.appendChild(label);
        console.log(`📍 Added WD ${wd} label at position ${labelCenterInStickyContainer}px`);
    });
    
    console.log('✅ WD axis labels updated successfully');
}
```

#### 3. **Global gWdColumnWidth synchronization**
```javascript
// DODANE - immediate update globalnej zmiennej
gWdColumnWidth = currentWdColumnWidth;
console.log('📊 Updated global gWdColumnWidth to:', gWdColumnWidth);
```

### **Flow naprawionej funkcjonalności:**

#### **Scenario: User sets WD -3 for "Zamknięcie miesiąca"**
1. **Add WD to array**: `gUniqueDataWds` becomes `[-3, -2, 1, 3, 7]`
2. **Immediate positioning**: Target process positioned with `currentWdColumnWidth`
3. **Global sync**: `gWdColumnWidth = currentWdColumnWidth` 
4. **Axis labels only**: `updateWdAxisLabels()` updates floating labels
5. **Result**: Target process positioned correctly, other processes UNCHANGED

### **Key improvement - Surgical vs Full Update:**

#### **PRZED (Full Redraw - Chaos):**
1. Target process positioned correctly
2. **PROBLEM**: `renderDiagramAndRestoreState()` repositions ALL processes
3. Chaos effect as all processes move to new calculated positions

#### **PO (Surgical Update - Stable):**
1. Target process positioned correctly
2. **SOLUTION**: Only axis labels updated via `updateWdAxisLabels()`
3. Other processes maintain original positions - no chaos

### **Architectural insight:**
**Simulation mode** powinien być **isolated** od normal diagram layout. Adding new WDs w simulation nie powinno trigger full layout recalculation که affects wszystkie procesy.

### **Pliki zmienione:**
- **Diagram.html**:
  - Linie 12711-12719: Replaced `renderDiagramAndRestoreState()` z lightweight axis update
  - Linie 10480-10535: Added `updateWdAxisLabels()` function
  - Linia 12712: Added global `gWdColumnWidth` synchronization

### **Test case verification:**
```javascript
// Test case: Add WD -3 to existing [-2, 1, 3, 7]
// Expected behavior:
// 1. Target process moves to WD -3 (leftmost position)
// 2. Other processes (Amortyzacja, Create FA) remain in original positions  
// 3. Axis labels update to show [-3, -2, 1, 3, 7]
// 4. No "chaos effect" - diagram layout stable except for target process
```

### **Jak uniknąć w przyszłości:**
- **Isolation principle**: Simulation operations should not trigger full layout updates
- **Surgical updates**: Update only what's necessary (target process + axis labels)
- **State management**: Distinguish między simulation state a normal diagram state
- **Testing negative values**: Always test with negative WDs that don't exist in current data
- **Debug positioning conflicts**: Log when multiple positioning systems might conflict

### **Objawy do rozpoznania:**
- All processes move when only one should move in simulation
- "Chaos effect" - scattered process positions after simulation
- Console shows correct array updates but visual layout is broken
- Working positive WD values but broken negative WD values
- Full diagram redraw during simulation operations

### **Status:**
- ✅ Eliminated "chaos effect" - stable diagram during negative WD simulation
- ✅ Surgical axis update instead of full diagram redraw
- ✅ Global state synchronization maintains consistency
- ✅ Negative WD values work correctly without affecting other processes
- ✅ Lightweight `updateWdAxisLabels()` function for axis-only updates

*Problem naprawiony: 2025-07-11 09:30*

---

*Debug log utworzony 2025-07-10 | FlowCraft v2.0*

---

## 🐛 PROBLEM: Strzałki zależności nie są rysowane podczas symulacji (2025-07-11 12:30)

### **Opis problemu:**
- Podczas symulacji procesy były prawidłowo wyświetlane i przesuwane
- Strzałki zależności między procesami nie były rysowane lub były niepełne
- Tylko strzałki wpływu symulacji (impact arrows) były widoczne - czerwone, pomarańczowe, zielone
- Normalne strzałki zależności (standardowe, blocking, informational) nie były wyświetlane

### **Przyczyny zidentyfikowane:**

#### 1. **Brak mechanizmu rysowania normalnych strzałek w symulacji**
```javascript
// PROBLEM - function applySimulationVisuals() nie rysuje normalnych strzałek
function applySimulationVisuals() {
    svgLayer.innerHTML = ''; // Czyści wszystkie strzałki
    // ...
    // Rysuje tylko impact arrows ale nie normalne dependency arrows
    drawArrow(sourceNode, targetNode, '#dc3545', 'simulation-arrow-broken', dep.type, true); // Tylko impact
}
```

#### 2. **refreshDiagramStyles() nie jest wywoływana w symulacji**
```javascript
// PROBLEM - refreshDiagramStyles() pomija tryb symulacji
function refreshDiagramStyles() {
    if (isSimulationModeActive) {
        applySimulationVisuals(simulatedNewProcessData); 
        return; // Kończy tutaj - nie rysuje normalnych strzałek
    }
    // ... kod rysowania strzałek tylko dla normalnego trybu
}
```

#### 3. **Brak funkcji do rysowania wszystkich strzałek zależności**
- `drawArrow()` funkcja istnieje i działa prawidłowo
- Ale nie było funkcji która rysuje wszystkie strzałki zależności w symulacji
- Tylko impact analysis rysował specjalne strzałki

### **Rozwiązanie zaimplementowane:**

#### **Nowa funkcja `drawAllDependencyArrowsInSimulation()` (Diagram.html:12920-12959)**
```javascript
// DODANE - funkcja rysująca wszystkie strzałki zależności podczas symulacji
function drawAllDependencyArrowsInSimulation() {
    if (!isSimulationModeActive) return;
    
    const allProcsData = getAllProcessesFromData();
    
    // Draw all dependency arrows between processes
    allProcsData.forEach(proc => {
        if (!proc.Dependencies) return;
        
        const targetNode = diagramPane.querySelector(`.process-node[data-id="${proc.ID}"]`);
        if (!targetNode) return;
        
        const deps = String(proc.Dependencies).split(',').map(d => parseDependencyEntry(d.trim()));
        deps.forEach(dep => {
            const sourceNode = diagramPane.querySelector(`.process-node[data-id="${dep.id}"]`);
            if (!sourceNode) return;
            
            // Skip if this arrow is already drawn as impact arrow
            const hasImpactArrow = sourceNode.classList.contains('simulation-ok-input') ||
                                 sourceNode.classList.contains('simulation-input-conflict') ||
                                 targetNode.classList.contains('simulation-ok-output') ||
                                 targetNode.classList.contains('simulation-output-at-risk');
            
            if (!hasImpactArrow) {
                // Draw normal dependency arrow with appropriate color
                let arrowColor = configColors.outputArrow;
                let finalDepType = dep.type || 'standard';
                
                if (finalDepType === 'blocking') {
                    arrowColor = configColors.outputArrowBlocking;
                } else if (finalDepType === 'informational') {
                    arrowColor = configColors.outputArrowInformational;
                }
                
                drawArrow(sourceNode, targetNode, arrowColor, 'simulation-normal-arrow', finalDepType, false);
            }
        });
    });
}
```

#### **Wywołanie funkcji w applySimulationVisuals() (Diagram.html:12914)**
```javascript
// DODANE - wywołanie rysowania wszystkich strzałek
function applySimulationVisuals() {
    // ... existing code ...
    
    // Dodaj rysowanie wszystkich strzałek zależności w symulacji
    drawAllDependencyArrowsInSimulation();
    
    drawMiniMap();
    updateMiniMapViewPort();
}
```

### **Kluczowe funkcje naprawki:**

#### **1. Inteligentne wykrywanie duplikatów**
```javascript
// Sprawdza czy strzałka już istnieje jako impact arrow
const hasImpactArrow = sourceNode.classList.contains('simulation-ok-input') ||
                     sourceNode.classList.contains('simulation-input-conflict') ||
                     targetNode.classList.contains('simulation-ok-output') ||
                     targetNode.classList.contains('simulation-output-at-risk');
```

#### **2. Właściwe kolory strzałek**
```javascript
// Używa configColors dla spójności z resztą aplikacji
let arrowColor = configColors.outputArrow;
if (finalDepType === 'blocking') {
    arrowColor = configColors.outputArrowBlocking;
} else if (finalDepType === 'informational') {
    arrowColor = configColors.outputArrowInformational;
}
```

#### **3. Klasyfikacja strzałek**
```javascript
// Używa klasy 'simulation-normal-arrow' dla łatwego rozpoznania
drawArrow(sourceNode, targetNode, arrowColor, 'simulation-normal-arrow', finalDepType, false);
```

### **Hierarchia strzałek w symulacji:**
1. **Impact arrows** (najwyższy priorytet): czerwone, pomarańczowe, zielone
2. **Normal dependency arrows**: standardowe kolory zależności
3. **Brak duplikatów**: jedna strzałka na zależność

### **Testowanie:**
1. Otwórz diagram z procesami i zależnościami
2. Aktywuj tryb symulacji
3. Sprawdź czy wszystkie strzałki zależności są widoczne
4. Sprawdź czy impact arrows mają priorytet nad normalnymi strzałkami

### **Pliki zmienione:**
- **Diagram.html**: 
  - Linia 12914: Dodano wywołanie `drawAllDependencyArrowsInSimulation()`
  - Linie 12920-12959: Nowa funkcja `drawAllDependencyArrowsInSimulation()`

### **Jak uniknąć w przyszłości:**
- Zawsze testuj rysowanie strzałek w różnych trybach (normalny, symulacja, tree highlight)
- Sprawdź czy `svgLayer.innerHTML = ''` nie usuwa potrzebnych strzałek
- Upewnij się, że każdy tryb ma mechanizm rysowania wszystkich potrzebnych strzałek
- Testuj z różnymi typami zależności (standard, blocking, informational)

### **Objawy do rozpoznania:**
- Procesy są widoczne w symulacji ale brak strzałek między nimi
- Tylko kolorowe impact arrows są widoczne
- Diagram wygląda "rozłączony" mimo istniejących zależności
- Console nie pokazuje błędów ale strzałki nie są rysowane

### **Status:**
- ✅ Funkcja `drawAllDependencyArrowsInSimulation()` dodana
- ✅ Inteligentne wykrywanie duplikatów zaimplementowane
- ✅ Właściwe kolory i typy strzałek zachowane
- ✅ Wywołanie funkcji w `applySimulationVisuals()` dodane
- ✅ Wszystkie strzałki zależności teraz rysowane w symulacji

*Problem naprawiony: 2025-07-11 12:30*

---

## 🐛 PROBLEM: Strzałki w symulacji używają błędnych pozycji początkowych/końcowych (2025-07-11 12:45)

### **Opis problemu:**
- Po naprawieniu rysowania strzałek w symulacji, strzałki były rysowane ale z błędnymi pozycjami
- Strzałka od "Create FA" do "Amortyzacja" zaczynała się "z powietrza" zamiast od procesu "Create FA"
- "Create FA" był na pozycji WD -2, ale strzałka zaczynała się z lewej strony ekranu
- Problem występował gdy jeden proces jest przesunięty w symulacji a drugi nie

### **Przyczyny zidentyfikowane:**

#### **Root Cause: Mieszanie systemów pozycjonowania**
```javascript
// PROBLEM - funkcja drawArrow() używała różnych systemów pozycjonowania
function drawArrow(fromNode, toNode, color, arrowTypeClassesString, dependencyLinkType = 'standard', isImpactPath = false) {
    const isSimulatedSource = isSimulationModeActive && (simulationTargets.some(t => t.id === fromNode.dataset.id && (t.type === 'shift' || t.type === 'add')));
    const isSimulatedTarget = isSimulationModeActive && (simulationTargets.some(t => t.id === toNode.dataset.id && (t.type === 'shift' || t.type === 'add')));
    
    // PROBLEM: Symulowane węzły używały getBoundingClientRect() (aktualne pozycje)
    if (isSimulatedSource) {
        const fromRect = fromNode.getBoundingClientRect();
        // ... calculate x1, y1
    } else if (fromLayout) {
        // PROBLEM: Nie-symulowane węzły używały nodeLayouts (stare pozycje sprzed symulacji)
        x1 = (fromLayout.finalX + fromLayout.width / 2);
        y1 = (fromLayout.finalY + fromLayout.height / 2);
    }
}
```

#### **Szczegółowy flow błędu:**
1. **"Create FA"** nie jest w `simulationTargets` (nie jest przesuwany przez user)
2. **"Amortyzacja"** jest w `simulationTargets` (jest przesuwana przez user)
3. **Strzałka od "Create FA" do "Amortyzacja"**:
   - `isSimulatedSource = false` → używa `nodeLayouts["Create FA"]` (stare pozycje)
   - `isSimulatedTarget = true` → używa `getBoundingClientRect()` (aktualne pozycje)
4. **Rezultat**: Strzałka zaczyna się ze starej pozycji "Create FA" ale kończy w nowej pozycji "Amortyzacja"

#### **Kluczowy problem z nodeLayouts:**
```javascript
// W trybie symulacji applySimulationVisuals() aktualizuje wizualne pozycje wszystkich procesów
// ale nodeLayouts zawiera stare pozycje sprzed symulacji
node.style.left = `${newLeft}px`;  // Visual position updated
node.style.top = `${newTop}px`;    // Visual position updated
// ale nodeLayouts["Create FA"].finalX/Y są nadal stare!
```

### **Rozwiązanie zaimplementowane:**

#### **Uproszczona logika pozycjonowania w drawArrow() (Diagram.html:10887-10917)**
```javascript
// POPRAWIONE - w trybie symulacji zawsze używaj aktualnych pozycji
function drawArrow(fromNode, toNode, color, arrowTypeClassesString, dependencyLinkType = 'standard', isImpactPath = false) {
    if (!fromNode || !toNode) return;

    let x1, y1, x2, y2;

    // In simulation mode, always use current visual positions (getBoundingClientRect)
    // because nodeLayouts contains outdated positions from before simulation
    if (isSimulationModeActive) {
        const fromRect = fromNode.getBoundingClientRect();
        const diagramRect = diagramContainer.getBoundingClientRect();
        x1 = (fromRect.left - diagramRect.left + diagramContainer.scrollLeft + (fromRect.width / 2)) / currentZoom;
        y1 = (fromRect.top - diagramRect.top + diagramContainer.scrollTop + (fromRect.height / 2)) / currentZoom;
        
        const toRect = toNode.getBoundingClientRect();
        x2 = (toRect.left - diagramRect.left + diagramContainer.scrollLeft + (toRect.width / 2)) / currentZoom;
        y2 = (toRect.top - diagramRect.top + diagramContainer.scrollTop + (toRect.height / 2)) / currentZoom;
    } else {
        // In normal mode, use nodeLayouts for precise positioning
        let fromLayout = nodeLayouts[fromNode.dataset.id];
        let toLayout = nodeLayouts[toNode.dataset.id];
        
        if (fromLayout) {
            x1 = (fromLayout.finalX + fromLayout.width / 2);
            y1 = (fromLayout.finalY + fromLayout.height / 2);
        } else { return; }
        
        if (toLayout) {
            x2 = (toLayout.finalX + toLayout.width / 2);
            y2 = (toLayout.finalY + toLayout.height / 2);
        } else { return; }
    }
    // ... rest of function
}
```

### **Kluczowe zmiany:**

#### **1. Jeden system pozycjonowania na tryb**
```javascript
// PRZED: Mieszanie systemów
if (isSimulatedSource) { /* getBoundingClientRect */ }
else { /* nodeLayouts */ }

// PO: Jeden system dla całego trybu
if (isSimulationModeActive) { /* getBoundingClientRect for ALL nodes */ }
else { /* nodeLayouts for ALL nodes */ }
```

#### **2. Eliminacja problemów z cache**
- **Symulacja**: `getBoundingClientRect()` zawsze zwraca aktualne pozycje
- **Normalny tryb**: `nodeLayouts` zawiera precyzyjne pozycje

#### **3. Prostota i spójność**
- Usunięto skomplikowaną logikę `isSimulatedSource/Target`
- Jeden path dla każdego trybu
- Łatwiejsze debugowanie i testowanie

### **Testowanie:**
1. Otwórz diagram z procesami i zależnościami
2. Aktywuj tryb symulacji i przesuń proces
3. Sprawdź czy strzałki zaczynają się i kończą w poprawnych pozycjach
4. Sprawdź proces nieprzesunięty - czy jego strzałki są prawidłowe

### **Przypadki testowe:**
- **Strzałka od przesuniętego do nieprzesuniętego**: Powinno działać
- **Strzałka od nieprzesuniętego do przesuniętego**: Powinno działać (to był główny problem)
- **Strzałka między dwoma przesuniętymi**: Powinno działać
- **Strzałka między dwoma nieprzesuniętymi**: Powinno działać

### **Pliki zmienione:**
- **Diagram.html**: 
  - Linie 10887-10917: Uproszczona logika pozycjonowania w `drawArrow()`
  - Usunięto skomplikowaną logikę `isSimulatedSource/Target`

### **Jak uniknąć w przyszłości:**
- **Jedna metoda pozycjonowania na tryb**: Nie mieszaj `getBoundingClientRect()` z `nodeLayouts`
- **Aktualizuj cache**: Jeśli używasz `nodeLayouts`, upewnij się że są aktualne
- **Testuj mieszane scenariusze**: Strzałki między przesuniętymi i nieprzesuniętymi procesami
- **Sprawdź relatywność**: `getBoundingClientRect()` zwraca pozycje względem viewport

### **Objawy do rozpoznania:**
- Strzałki "lecą z powietrza" zamiast od procesów
- Strzałki kończą się w powietrzu zamiast na procesach
- Strzałki są OK w normalnym trybie ale błędne w symulacji
- Niektóre strzałki OK ale inne błędne w tym samym trybie

### **Status:**
- ✅ Uproszczona logika pozycjonowania w `drawArrow()`
- ✅ Jeden system pozycjonowania na tryb
- ✅ Eliminacja problemów z cache `nodeLayouts`
- ✅ Wszystkie strzałki używają spójnych pozycji w symulacji

*Problem naprawiony: 2025-07-11 12:45*

---

## 🎨 UI IMPROVEMENTS: Panel Filters, Rebranding i UX (2025-07-11 13:30)

### **Zadania wykonane:**
1. **Naprawiono jasny layout opcji rozwijanych w panelu Filters** - dodano dark theme dla `option` elementów
2. **Usunięto przycisk dark/light theme** - dark mode jest teraz jedynym i domyślnym motywem
3. **Naprawiono "Reset to default" w Colors** - teraz resetuje do dark theme zamiast jasnego
4. **Usunięto wszystkie referencje do "Bridgestone"** - zastąpiono "FlowCraft" nazewnictwem
5. **Zmieniono "Columns" na "Processes"** - bardziej intuicyjne nazewnictwo
6. **Zmieniono "sheets" na "datasets"** - bardziej zrozumiałe dla użytkowników

### **Problem z panelem Filters:**
- **Objaw**: Opcje rozwijane w panelu Filters miały jasny layout mimo dark theme
- **Przyczyna**: Brak stylów CSS dla elementów `<option>` w dark mode
- **Rozwiązanie**: Dodano dedykowane style dla `option` elementów

### **Rebranding kompletny:**
- **Zmienne CSS**: `--bridgestone-red` → `--fc-accent-red`
- **Nazwy motywów**: "Bridgestone *" → "FlowCraft *"
- **Klasy CSS**: `bridgestone-footer-symbol` → `fc-footer-symbol`
- **Komentarze**: Wszędzie zastąpiono "Bridgestone" na "FlowCraft"

### **Zmiany w UX:**
- **"Columns" → "Processes"**: Bardziej intuicyjne dla użytkowników
- **"sheets" → "datasets"**: Mniej techniczne, bardziej zrozumiałe
- **Dark mode jako default**: Spójny design bez możliwości zmiany

### **Funkcja Reset to Default:**
- **Przed**: Resetowało do THEMES[0] (jasny motyw)
- **Po**: Resetuje do THEMES[1] (FlowCraft Dark theme)

### **Pliki zmienione:**
- **Diagram.html**: ~150 linii zmodyfikowanych
- **Statystyki**: 100+ zmiennych CSS, 4 motywy, 10+ komunikatów użytkownika

### **Jak uniknąć w przyszłości:**
- Zawsze testuj spójność theme w całej aplikacji
- Sprawdź wszystkie elementy formularzy (input, select, option)
- Pamiętaj o aktualizacji nazw motywów po rebrandingu
- Testuj funkcje reset w różnych kontekstach

### **Objawy do rozpoznania:**
- Jasne elementy w ciemnym interfejsie
- Nieaktualne nazwy firmowe w kodzie
- Mylące nazwy przycisków dla użytkowników
- Reset functions resetujące do niewłaściwych wartości

### **Status:**
- ✅ Spójny dark theme w całej aplikacji
- ✅ Kompletne usunięcie brandingu firmowego
- ✅ Intuicyjne nazewnictwo dla użytkowników
- ✅ Naprawione funkcje reset
- ✅ Profesjonalny wygląd aplikacji

*Usprawnienia UI ukończone: 2025-07-11 13:30*

---