# Advanced

## Note for Windows Users

If you encounter issues with character encoding, such as misrepresentation of "plusminus" (±) or "sigma" (σ) symbols in the benchmark results, it's likely due to Windows using UTF-16 LE encoding by default. To ensure characters are displayed correctly, you can switch your system to use UTF-8 encoding by following these steps:

1. Open **Control Panel**.
2. Navigate to **Region** > **Administrative** tab.
3. Click on **Change system locale...**.
4. Check the option for **Beta: Use Unicode UTF-8 for worldwide language support**.
5. Click **OK** and restart your computer if prompted.

This setting will configure your system to use UTF-8 encoding for non-Unicode programs, which should resolve any character display issues in the benchmark output.

[Zig console output encoding issue](https://github.com/ziglang/zig/issues/7600#issuecomment-753563786)
