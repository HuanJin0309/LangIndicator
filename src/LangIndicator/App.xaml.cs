using System.Threading;
using System.Windows;

namespace LangIndicator;

public partial class App
{
    private const string SingleInstanceMutexName = @"Local\LangIndicator_SingleInstance";

    private static Mutex? _singleInstanceMutex;
    private static bool _isNewInstance;

    protected override void OnStartup(StartupEventArgs e)
    {
        _singleInstanceMutex = new Mutex(false, SingleInstanceMutexName);
        try
        {
            _isNewInstance = _singleInstanceMutex.WaitOne(0);
        }
        catch (AbandonedMutexException)
        {
            // 上一个实例异常退出后互斥体被遗弃，当前实例接管
            _isNewInstance = true;
        }

        if (!_isNewInstance)
        {
            // 已有一个实例在运行，静默退出，避免出现多个指示器
            Shutdown();
            return;
        }

        base.OnStartup(e);
    }

    protected override void OnExit(ExitEventArgs e)
    {
        if (_isNewInstance)
        {
            try
            {
                _singleInstanceMutex?.ReleaseMutex();
            }
            catch (ApplicationException)
            {
                // 互斥体未被当前线程持有（正常退出时已释放），忽略
            }
        }

        _singleInstanceMutex?.Dispose();
        base.OnExit(e);
    }
}
