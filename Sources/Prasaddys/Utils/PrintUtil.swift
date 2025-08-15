public struct PrintUtil {
    public static func printDebug(data: String) {
#if DEBUG
        print(data)
#endif
    }
}
