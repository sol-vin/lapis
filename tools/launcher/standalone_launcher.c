#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shellapi.h>
#include <shlobj.h>
#include <stdint.h>

const uint32_t LAPZ_MAGIC = 0x5A50414C;

static int file_exists(const wchar_t* path) {
    DWORD dw = GetFileAttributesW(path);
    return (dw != INVALID_FILE_ATTRIBUTES && !(dw & FILE_ATTRIBUTE_DIRECTORY));
}

static int run_process(wchar_t* cmd, const wchar_t* workdir, DWORD creationFlags, int showWindow) {
    STARTUPINFOW si;
    PROCESS_INFORMATION pi;
    ZeroMemory(&si, sizeof(si));
    si.cb = sizeof(si);
    if (!showWindow) {
        si.dwFlags |= STARTF_USESHOWWINDOW;
        si.wShowWindow = SW_HIDE;
    }
    ZeroMemory(&pi, sizeof(pi));

    if (!CreateProcessW(NULL, cmd, NULL, NULL, TRUE, creationFlags, NULL, workdir, &si, &pi)) {
        return -1;
    }

    WaitForSingleObject(pi.hProcess, INFINITE);
    DWORD exitCode = 0;
    GetExitCodeProcess(pi.hProcess, &exitCode);
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);
    return (int)exitCode;
}

int WINAPI wWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, PWSTR pCmdLine, int nCmdShow) {
    wchar_t selfPath[MAX_PATH * 4];
    GetModuleFileNameW(NULL, selfPath, MAX_PATH * 4);

    wchar_t selfDir[MAX_PATH * 4];
    lstrcpyW(selfDir, selfPath);
    wchar_t* lastSlash = wcsrchr(selfDir, L'\\');
    if (lastSlash) *lastSlash = L'\0';

    // 1. In-place detection: if running inside unzipped directory containing bridge DLL & runner
    wchar_t localBridge[MAX_PATH * 4];
    wsprintfW(localBridge, L"%s\\crystal_bridge.dll", selfDir);
    wchar_t localRunner[MAX_PATH * 4];
    wsprintfW(localRunner, L"%s\\soulantern_runner.exe", selfDir);
    if (!file_exists(localRunner)) {
        wsprintfW(localRunner, L"%s\\game_runner.exe", selfDir);
    }

    if (file_exists(localBridge) && file_exists(localRunner)) {
        wchar_t fullCmd[MAX_PATH * 8];
        wsprintfW(fullCmd, L"\"%s\" %s", localRunner, pCmdLine);
        return run_process(fullCmd, selfDir, 0, 1);
    }

    // 2. Standalone execution: extract embedded payload to %LOCALAPPDATA%\Soulantern\app
    wchar_t localAppData[MAX_PATH];
    if (FAILED(SHGetFolderPathW(NULL, CSIDL_LOCAL_APPDATA, NULL, 0, localAppData))) {
        GetTempPathW(MAX_PATH, localAppData);
    }

    wchar_t parentAppDir[MAX_PATH * 4];
    wsprintfW(parentAppDir, L"%s\\Soulantern", localAppData);
    CreateDirectoryW(parentAppDir, NULL);

    wchar_t appDir[MAX_PATH * 4];
    wsprintfW(appDir, L"%s\\Soulantern\\app", localAppData);
    CreateDirectoryW(appDir, NULL);

    HANDLE hFile = CreateFileW(selfPath, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, 0, NULL);
    if (hFile != INVALID_HANDLE_VALUE) {
        LARGE_INTEGER liSize;
        GetFileSizeEx(hFile, &liSize);
        uint64_t fileSize = liSize.QuadPart;

        if (fileSize > 12) {
            LARGE_INTEGER liSeek;
            liSeek.QuadPart = fileSize - 12;
            SetFilePointerEx(hFile, liSeek, NULL, FILE_BEGIN);

            uint64_t payloadSize = 0;
            uint32_t magic = 0;
            DWORD bytesRead = 0;
            ReadFile(hFile, &payloadSize, 8, &bytesRead, NULL);
            ReadFile(hFile, &magic, 4, &bytesRead, NULL);

            if (magic == LAPZ_MAGIC && payloadSize > 0 && payloadSize < fileSize) {
                wchar_t verFile[MAX_PATH * 4];
                wsprintfW(verFile, L"%s\\version.txt", appDir);

                char expectedVer[128];
                wsprintfA(expectedVer, "%llu_%llu\n", payloadSize, fileSize);

                int needsExtract = 1;
                HANDLE hVf = CreateFileW(verFile, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, 0, NULL);
                if (hVf != INVALID_HANDLE_VALUE) {
                    char readVer[128] = {0};
                    DWORD rBytes = 0;
                    ReadFile(hVf, readVer, sizeof(readVer) - 1, &rBytes, NULL);
                    CloseHandle(hVf);
                    if (lstrcmpA(readVer, expectedVer) == 0) {
                        needsExtract = 0;
                    }
                }

                if (needsExtract) {
                    wchar_t tempDir[MAX_PATH];
                    GetTempPathW(MAX_PATH, tempDir);
                    wchar_t zipPath[MAX_PATH * 4];
                    wsprintfW(zipPath, L"%ssoulantern_payload.zip", tempDir);

                    LARGE_INTEGER liPayloadSeek;
                    liPayloadSeek.QuadPart = fileSize - 12 - payloadSize;
                    SetFilePointerEx(hFile, liPayloadSeek, NULL, FILE_BEGIN);

                    HANDLE hZip = CreateFileW(zipPath, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, 0, NULL);
                    if (hZip != INVALID_HANDLE_VALUE) {
                        const DWORD CHUNK = 64 * 1024;
                        BYTE* buf = (BYTE*)VirtualAlloc(NULL, CHUNK, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
                        uint64_t remaining = payloadSize;
                        while (remaining > 0) {
                            DWORD toRead = (DWORD)(CHUNK < remaining ? CHUNK : remaining);
                            ReadFile(hFile, buf, toRead, &bytesRead, NULL);
                            if (bytesRead == 0) break;
                            DWORD bytesWritten = 0;
                            WriteFile(hZip, buf, bytesRead, &bytesWritten, NULL);
                            remaining -= bytesRead;
                        }
                        VirtualFree(buf, 0, MEM_RELEASE);
                        CloseHandle(hZip);

                        wchar_t tarCmd[MAX_PATH * 8];
                        wsprintfW(tarCmd, L"tar.exe -xf \"%s\" -C \"%s\"", zipPath, appDir);
                        int tarRes = run_process(tarCmd, appDir, CREATE_NO_WINDOW, 0);
                        if (tarRes != 0) {
                            wchar_t psCmd[MAX_PATH * 8];
                            wsprintfW(psCmd, L"powershell.exe -NoProfile -NonInteractive -WindowStyle Hidden -Command \"Expand-Archive -Path '%s' -DestinationPath '%s' -Force\"", zipPath, appDir);
                            run_process(psCmd, appDir, CREATE_NO_WINDOW, 0);
                        }
                        DeleteFileW(zipPath);

                        HANDLE hVfOut = CreateFileW(verFile, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, 0, NULL);
                        if (hVfOut != INVALID_HANDLE_VALUE) {
                            DWORD wBytes = 0;
                            WriteFile(hVfOut, expectedVer, lstrlenA(expectedVer), &wBytes, NULL);
                            CloseHandle(hVfOut);
                        }
                    }
                }
            }
        }
        CloseHandle(hFile);
    }

    wchar_t stagedRunner[MAX_PATH * 4];
    wsprintfW(stagedRunner, L"%s\\soulantern_runner.exe", appDir);
    if (!file_exists(stagedRunner)) {
        wsprintfW(stagedRunner, L"%s\\soulantern.exe", appDir);
    }
    if (!file_exists(stagedRunner)) {
        wsprintfW(stagedRunner, L"%s\\game_runner.exe", appDir);
    }

    if (file_exists(stagedRunner)) {
        wchar_t fullCmd[MAX_PATH * 8];
        wsprintfW(fullCmd, L"\"%s\" %s", stagedRunner, pCmdLine);
        return run_process(fullCmd, appDir, 0, 1);
    }

    MessageBoxW(NULL, L"Failed to launch Soulantern. Could not locate engine binaries in package payload.", L"Soulantern Launch Error", MB_ICONERROR | MB_OK);
    return 1;
}
