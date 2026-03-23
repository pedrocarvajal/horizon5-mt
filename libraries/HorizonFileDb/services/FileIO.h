#ifndef HORIZON_FDB_FILE_IO_H
#define HORIZON_FDB_FILE_IO_H

#define WIN32_LEAN_AND_MEAN
#include <windows.h>

#include <string>
#include <vector>

class FileIO {
public:
    static bool ReadFile(const std::wstring& filePath, std::string& output)
    {
        HANDLE hFile = CreateFileW(
            filePath.c_str(),
            GENERIC_READ,
            FILE_SHARE_READ,
            NULL,
            OPEN_EXISTING,
            FILE_ATTRIBUTE_NORMAL,
            NULL);

        if (hFile == INVALID_HANDLE_VALUE) {
            return false;
        }

        LARGE_INTEGER fileSize;
        if (!GetFileSizeEx(hFile, &fileSize)) {
            CloseHandle(hFile);
            return false;
        }

        if (fileSize.QuadPart == 0) {
            CloseHandle(hFile);
            output.clear();
            return true;
        }

        output.resize(static_cast<size_t>(fileSize.QuadPart));

        DWORD bytesRead = 0;
        BOOL success = ::ReadFile(hFile, &output[0], static_cast<DWORD>(fileSize.QuadPart), &bytesRead, NULL);
        CloseHandle(hFile);

        if (!success) {
            output.clear();
            return false;
        }

        output.resize(bytesRead);
        return true;
    }

    static bool WriteFile(const std::wstring& filePath, const char* data, size_t dataSize)
    {
        EnsureDirectoryExists(filePath);

        HANDLE hFile = CreateFileW(
            filePath.c_str(),
            GENERIC_WRITE,
            0,
            NULL,
            CREATE_ALWAYS,
            FILE_ATTRIBUTE_NORMAL,
            NULL);

        if (hFile == INVALID_HANDLE_VALUE) {
            return false;
        }

        DWORD bytesWritten = 0;
        BOOL success = ::WriteFile(hFile, data, static_cast<DWORD>(dataSize), &bytesWritten, NULL);
        CloseHandle(hFile);

        return success && bytesWritten == static_cast<DWORD>(dataSize);
    }

    static bool DeleteFileByPath(const std::wstring& filePath)
    {
        return DeleteFileW(filePath.c_str()) != 0;
    }

    static void EnsureDirectoryExists(const std::wstring& filePath)
    {
        size_t lastSep = filePath.find_last_of(L"\\/");

        if (lastSep == std::wstring::npos || lastSep == 0) {
            return;
        }

        std::wstring directory = filePath.substr(0, lastSep);
        CreateDirectoryRecursive(directory);
    }

private:
    static void CreateDirectoryRecursive(const std::wstring& path)
    {
        DWORD attributes = GetFileAttributesW(path.c_str());

        if (attributes != INVALID_FILE_ATTRIBUTES && (attributes & FILE_ATTRIBUTE_DIRECTORY)) {
            return;
        }

        size_t separator = path.find_last_of(L"\\/");

        if (separator != std::wstring::npos && separator > 0) {
            std::wstring parent = path.substr(0, separator);

            if (parent.length() > 2 || (parent.length() == 2 && parent[1] != L':')) {
                CreateDirectoryRecursive(parent);
            }
        }

        CreateDirectoryW(path.c_str(), NULL);
    }
};

#endif
