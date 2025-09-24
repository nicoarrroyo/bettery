// ===================================================================================
// BATTERY MONITOR - REFACTORED
// ===================================================================================

#include <windows.h>
#include <string>
#include <sstream>
#include <vector>
#include <ctime>
#include <iostream>

// ===================================================================================
// GLOBAL VARIABLES
// ===================================================================================
HWND labelBatteryInfo;     // Label showing battery text
HWND toggleButton;         // "Always on Top" button
HWND closeButton;          // Custom 'X' close button

bool isTopMost = true;      // Track "Always on Top" state
std::vector<int> runtimeLog; // Recent battery runtime estimates
int runtimeSum = 0;          // Running sum of runtime values
const int MAX_ENTRIES = 10; // Max history size

const UINT_PTR MAIN_UPDATE_TIMER_ID = 1; // Unique ID for main timer

// ===================================================================================
// HELPER FUNCTION: GetBatteryStatusText
// ===================================================================================
std::wstring GetBatteryStatusText() {
    SYSTEM_POWER_STATUS status;
    if (!GetSystemPowerStatus(&status)) {
        return L"Unable to retrieve info";
    }

    int percent = status.BatteryLifePercent;
    int runtime = status.BatteryLifeTime;

    std::wstringstream ss;
    ss << L"Charge: " << percent << L"%\n";

    if (runtime == -1) {
        ss << L"(Charging)";
        return ss.str();
    }

    int runtimeMinutes = runtime / 60;

    // Update history + running sum
    if (runtimeLog.empty() || runtimeLog.back() != runtimeMinutes) {
        runtimeLog.push_back(runtimeMinutes);
        runtimeSum += runtimeMinutes;
        if (runtimeLog.size() > MAX_ENTRIES) {
            runtimeSum -= runtimeLog.front();
            runtimeLog.erase(runtimeLog.begin());
        }
    }

    // Compute average runtime
    int avgMinutes = runtimeSum / runtimeLog.size();
    int hours = avgMinutes / 60;
    int minutes = avgMinutes % 60;
    ss << L"Time: " << hours << L"h " << minutes << L"m";

    return ss.str();
}

// ===================================================================================
// WINDOW PROCEDURE
// ===================================================================================
LRESULT CALLBACK WindowProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam) {
    switch (uMsg) {

    case WM_NCHITTEST: {
        LRESULT hit = DefWindowProc(hwnd, uMsg, wParam, lParam);
        return (hit == HTCLIENT) ? HTCAPTION : hit;
    }

    case WM_COMMAND: {
        if ((HWND)lParam == toggleButton) {
            // Toggle Always on Top
            isTopMost = !isTopMost;
            SetWindowPos(hwnd, isTopMost ? HWND_TOPMOST : HWND_NOTOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);
            SetWindowText(toggleButton, isTopMost ? L"On Top: ON" : L"On Top: OFF");
        }
        else if ((HWND)lParam == closeButton) {
            DestroyWindow(hwnd);
        }
        break;
    }

    case WM_TIMER: {
        if (wParam == MAIN_UPDATE_TIMER_ID) {
            std::wstring batteryText = GetBatteryStatusText();
            SetWindowText(labelBatteryInfo, batteryText.c_str());
        }
        break;
    }

    case WM_DESTROY: {
        KillTimer(hwnd, MAIN_UPDATE_TIMER_ID);
        PostQuitMessage(0);
        return 0;
    }
    }

    return DefWindowProc(hwnd, uMsg, wParam, lParam);
}

// ===================================================================================
// WINMAIN : APPLICATION ENTRY POINT
// ===================================================================================
int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow) {
    const wchar_t CLASS_NAME[] = L"BatteryMonitorClass";

    // Register window class
    WNDCLASS wc = {};
    wc.lpfnWndProc = WindowProc;
    wc.hInstance = hInstance;
    wc.lpszClassName = CLASS_NAME;
    wc.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
    RegisterClass(&wc);

    // Window dimensions
    int windowWidth = 104;
    int windowHeight = 54;

    // Center on screen
    int screenWidth = GetSystemMetrics(SM_CXSCREEN);
    int screenHeight = GetSystemMetrics(SM_CYSCREEN);
    int posX = (screenWidth - windowWidth) / 2;
    int posY = (screenHeight - windowHeight) / 2;

    // Create main window
    HWND hwnd = CreateWindowEx(
        0,
        CLASS_NAME,
        L"bettery",
        WS_POPUP | WS_BORDER,
        posX, posY, windowWidth, windowHeight,
        nullptr, nullptr, hInstance, nullptr
    );
    if (!hwnd) return 0;

    // Custom font
    HFONT hFont = CreateFont(
        14, 0, 0, 0, FW_NORMAL,
        FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
        DEFAULT_QUALITY, DEFAULT_PITCH | FF_SWISS,
        L"Segoe UI"
    );

    // Child controls
    labelBatteryInfo = CreateWindow(L"STATIC", L"Initializing...", WS_CHILD | WS_VISIBLE,
        2, 2, 80, 30, hwnd, nullptr, hInstance, nullptr);
    toggleButton = CreateWindow(L"BUTTON", L"On Top: ON", WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
        2, 32, 70, 20, hwnd, (HMENU)1, hInstance, nullptr);
    closeButton = CreateWindow(L"BUTTON", L"X", WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON,
        82, 0, 20, 20, hwnd, (HMENU)2, hInstance, nullptr);

    // Apply font
    SendMessage(labelBatteryInfo, WM_SETFONT, (WPARAM)hFont, TRUE);
    SendMessage(toggleButton, WM_SETFONT, (WPARAM)hFont, TRUE);
    SendMessage(closeButton, WM_SETFONT, (WPARAM)hFont, TRUE);

    // Initial setup
    SetWindowPos(hwnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE);
    SetTimer(hwnd, MAIN_UPDATE_TIMER_ID, 2000, NULL); // 20 second update
    ShowWindow(hwnd, nCmdShow);
    UpdateWindow(hwnd);

    // Message loop
    MSG msg = {};
    while (GetMessage(&msg, nullptr, 0, 0)) {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }

    // Cleanup
    DeleteObject(hFont);
    return 0;
}
