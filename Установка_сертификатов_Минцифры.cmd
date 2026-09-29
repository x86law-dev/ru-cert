@echo off
chcp 866 >nul
setlocal EnableExtensions
title Установка сертификатов Минцифры

rem ============================================================================
rem  Установка сертификатов НУЦ Минцифры России (Windows 10/11)
rem  по инструкции с портала Госуслуг: https://www.gosuslugi.ru/landing/crt
rem
rem  Скрипт:
rem    1. Скачивает корневой и выпускающий сертификаты с официального
rem       домена gu-st.ru;
rem    2. Проверяет, что скачаны именно сертификаты (PEM), и их хэши SHA-256;
rem    3. Устанавливает: корневой - в "Доверенные корневые центры
rem       сертификации", выпускающий - в "Промежуточные центры сертификации";
rem    4. Проверяет результат.
rem
rem  Запуск: двойной щелчок по файлу.
rem  Для установки на весь компьютер - запуск от имени администратора
rem  (иначе сертификаты встанут только для текущего пользователя).
rem ============================================================================

set "ROOT_URL=https://gu-st.ru/content/lending/russian_trusted_root_ca_pem.crt"
set "SUB_URL=https://gu-st.ru/content/lending/russian_trusted_sub_ca_pem.crt"
set "ROOT_FILE=%TEMP%\russian_trusted_root_ca_pem.crt"
set "SUB_FILE=%TEMP%\russian_trusted_sub_ca_pem.crt"
rem Хэши SHA-256 самих файлов (проверены 29.09.2026)
set "ROOT_HASH=936a43fea6e8e525bcc0f81acd9c3d21b4fc4b9b68acea7906d698005afc6504"
set "SUB_HASH=f0ae589f36774f29ef3648f7984b08d42fcce6f1ffeeb6236d773daeb2744ea6"

echo.
echo === Установка сертификатов НУЦ Минцифры России ===
echo.

rem --- Проверка прав администратора -------------------------------------------
net session >nul 2>&1
if %errorlevel%==0 (
    set "USERFLAG="
    echo [i] Запущено с правами администратора: установка для всего компьютера.
) else (
    set "USERFLAG=-user"
    echo [i] Прав администратора нет: установка только для текущего пользователя.
    echo     Для установки на весь компьютер перезапустите файл
    echo     от имени администратора.
)
echo.

rem --- Шаг 1. Скачивание -------------------------------------------------------
echo [1/4] Скачивание сертификатов...
curl.exe -fsSL -o "%ROOT_FILE%" "%ROOT_URL%"
if errorlevel 1 goto :dl_error
echo       Russian Trusted Root CA - скачан.
curl.exe -fsSL -o "%SUB_FILE%" "%SUB_URL%"
if errorlevel 1 goto :dl_error
echo       Russian Trusted Sub CA - скачан.
echo.

rem --- Шаг 2. Проверка скачанных файлов ----------------------------------------
echo [2/4] Проверка файлов...

rem 2.1. Это действительно сертификаты, а не страницы-заглушки?
findstr /c:"BEGIN CERTIFICATE" "%ROOT_FILE%" >nul
if errorlevel 1 goto :hash_error
findstr /c:"BEGIN CERTIFICATE" "%SUB_FILE%" >nul
if errorlevel 1 goto :hash_error

rem 2.2. Хэши SHA-256 совпадают с эталонными?
certutil -hashfile "%ROOT_FILE%" SHA256 | findstr /i "%ROOT_HASH%" >nul
if errorlevel 1 goto :hash_error
echo       Russian Trusted Root CA - подлинность подтверждена.
certutil -hashfile "%SUB_FILE%" SHA256 | findstr /i "%SUB_HASH%" >nul
if errorlevel 1 goto :hash_error
echo       Russian Trusted Sub CA - подлинность подтверждена.
echo.

rem --- Шаг 3. Установка --------------------------------------------------------
echo [3/4] Установка в хранилища сертификатов...
echo       Если появится окно с предупреждением безопасности - нажмите "Да".
certutil %USERFLAG% -addstore -f Root "%ROOT_FILE%"
if errorlevel 1 goto :install_error
certutil %USERFLAG% -addstore -f CA "%SUB_FILE%"
if errorlevel 1 goto :install_error
echo.

rem --- Шаг 4. Проверка результата ----------------------------------------------
echo [4/4] Проверка установки...
set "CHECKFAIL=0"
certutil %USERFLAG% -store Root | findstr /i "Russian Trusted Root CA" >nul
if errorlevel 1 ( echo       [ОШИБКА] Russian Trusted Root CA не найден! & set "CHECKFAIL=1" ) else ( echo       [OK] Russian Trusted Root CA - в хранилище "Доверенные корневые ЦС". )
certutil %USERFLAG% -store CA | findstr /i "Russian Trusted Sub CA" >nul
if errorlevel 1 ( echo       [ОШИБКА] Russian Trusted Sub CA не найден! & set "CHECKFAIL=1" ) else ( echo       [OK] Russian Trusted Sub CA - в хранилище "Промежуточные ЦС". )
echo.

if "%CHECKFAIL%"=="1" goto :verify_error

del /q "%ROOT_FILE%" "%SUB_FILE%" >nul 2>&1

echo ============================================================
echo  ГОТОВО! Сертификаты Минцифры успешно установлены.
echo.
echo  Перезапустите браузер, чтобы изменения вступили в силу.
echo.
echo  Примечание: Firefox использует собственное хранилище -
echo  для него импортируйте сертификаты вручную через
echo  Настройки -^> Сертификаты -^> Импорт.
echo ============================================================
echo.
pause
exit /b 0

:dl_error
echo.
echo [ОШИБКА] Не удалось скачать сертификаты.
echo Проверьте подключение к интернету и настройки антивируса/файрвола.
goto :fail

:hash_error
echo.
echo [ОШИБКА] Скачанный файл не прошёл проверку подлинности!
echo Возможные причины:
echo   - файл подменён в сети (антивирус/прокси) - это опасно;
echo   - Минцифры обновили сертификат на сервере.
echo Установка прервана из соображений безопасности.
goto :fail

:install_error
echo.
echo [ОШИБКА] Не удалось установить сертификат в хранилище.
echo Попробуйте запустить файл от имени администратора.
goto :fail

:verify_error
echo [ОШИБКА] Сертификаты не найдены в хранилище после установки.
goto :fail

:fail
echo.
pause
exit /b 1
