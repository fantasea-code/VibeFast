using System;
using System.Runtime.InteropServices;
using System.Text;

class Program
{
    [DllImport("user32.dll", SetLastError = true)]
    public static extern uint GetRawInputDeviceList(IntPtr pRawInputDeviceList, ref uint puiNumDevices, uint cbSize);

    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern uint GetRawInputDeviceInfo(IntPtr hDevice, uint uiCommand, StringBuilder pData, ref uint pcbSize);

    static void Main()
    {
        uint numDevices = 0;
        uint structSize = (uint)(IntPtr.Size == 8 ? 16 : 8);

        GetRawInputDeviceList(IntPtr.Zero, ref numDevices, structSize);
        if (numDevices == 0) return;

        IntPtr pRawInputDeviceList = Marshal.AllocHGlobal((int)(structSize * numDevices));
        GetRawInputDeviceList(pRawInputDeviceList, ref numDevices, structSize);

        Console.WriteLine("=== RAW INPUT DEVICES ===");

        for (int i = 0; i < numDevices; i++)
        {
            IntPtr hDevice = Marshal.ReadIntPtr(pRawInputDeviceList, i * (int)structSize);
            uint size = 0;
            
            GetRawInputDeviceInfo(hDevice, 0x20000007, null, ref size);
            if (size > 0)
            {
                StringBuilder sb = new StringBuilder((int)size);
                GetRawInputDeviceInfo(hDevice, 0x20000007, sb, ref size);
                Console.WriteLine(sb.ToString());
            }
        }

        Marshal.FreeHGlobal(pRawInputDeviceList);
        Console.WriteLine("=========================");
    }
}
