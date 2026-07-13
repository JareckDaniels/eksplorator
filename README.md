# Eksplorator

Prosty menedzer plikow na Androida.

## Funkcje

- Przegladanie pamieci wewnetrznej (breadcrumb, cofanie przyciskiem wstecz)
- Zaznaczanie wielokrotne (dlugie przytrzymanie)
- Kopiuj / Wytnij / Wklej (schowek dziala miedzy folderami)
- Usun (z potwierdzeniem)
- Zmien nazwe, Nowy folder
- ZIP: rozpakuj, spakuj zaznaczone, podglad zawartosci bez rozpakowywania
- Otwieranie plikow domyslnymi aplikacjami systemu
- Udostepnianie (share sheet)
- Wyszukiwarka (rekurencyjna, w biezacym folderze)
- Zakladki (ulubione foldery)
- Miniatury zdjec
- Motyw jasny / ciemny / systemowy
- Sortowanie: nazwa, data, rozmiar, typ

## Build

Push do `main` -> GitHub Actions zbuduje APK.
APK w zakladce Actions -> artefakt `eksplorator-apk`.

## Staly podpis (wazne)

Pierwszy build wygeneruje keystore i wrzuci go jako artefakt `keystore-base64`.

1. Pobierz `keystore.b64.txt`
2. Skopiuj cala zawartosc
3. Settings -> Secrets and variables -> Actions -> New repository secret
4. Nazwa: `KEYSTORE_B64`, wartosc: zawartosc pliku

Od tej pory kazdy build bedzie podpisany tym samym kluczem -> aktualizacje
instaluja sie na wierzch, bez odinstalowywania.

## Uprawnienia

Aplikacja prosi o "Dostep do wszystkich plikow" (MANAGE_EXTERNAL_STORAGE).
Bez tego Android 11+ nie pozwoli na swobodne kopiowanie i usuwanie.
Ta aplikacja nie przejdzie weryfikacji Google Play - to build do wlasnego
uzytku (sideload).
