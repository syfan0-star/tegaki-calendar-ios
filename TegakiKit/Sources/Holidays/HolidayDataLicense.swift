import Foundation

/// The licence of the holiday data (docs/M7B_CONTRACT.md §5.9): python-holidays, MIT.
///
/// The app shows HolidayData/LICENSE-python-holidays.txt and CONTRIBUTORS-python-holidays.txt in
/// 設定 › 情報 › 「オープンソースのライセンス」; this copy and the link are what it shows when the files
/// cannot be read. KitChecks checks that `mitText` is the file byte for byte. When the data is made
/// with another version of python-holidays (§5.11), copy the new LICENSE here and change the version
/// in `contributorsURL`.
public enum HolidayDataLicense {
    /// LICENSE-python-holidays.txt (python-holidays 0.107), byte for byte. Its first line points at the
    /// CONTRIBUTORS file, so the two together are the complete notice.
    public static let mitText = #"""
    Copyright (c) Vacanza Team and individual contributors (see CONTRIBUTORS file)
    Copyright (c) dr-prodigy <dr.prodigy.github@gmail.com>, 2017-2023
    Copyright (c) ryanss <ryanssdev@icloud.com>, 2014-2017

    All rights reserved.

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in
    all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
    THE SOFTWARE.

    """#

    /// The CONTRIBUTORS file of the same version.
    public static let contributorsURL = URL(string: "https://github.com/vacanza/holidays/blob/v0.107/CONTRIBUTORS")!
}
