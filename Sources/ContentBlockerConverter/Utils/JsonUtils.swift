import Foundation

/**
 Helper class for encoding JSON without using the standard encoder (which is extremely slow).
 */
class JsonUtils {

    /**
     Encodes string array to a JSON.
     - Parameter arr: array to encode
     - Parameter escape: if true, escape the strings in that array. Otherwise, just concatenate as is.
     */
    public static func encodeStringArray(arr: [String], escape: Bool = false) -> String {
        var result = "[";

        for index in 0..<arr.count {
            if (index > 0) {
                result.append(",");
            }

            result.append("\"");
            result.append(escape ? arr[index].escapeForJSON() : arr[index]);
            result.append("\"");
        }

        result.append("]");

        return result;
    }
}
