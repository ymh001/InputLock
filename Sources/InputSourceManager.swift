import AppKit
import Carbon.HIToolbox

struct InputSource: Equatable {
    let sourceID: String
    let localizedName: String
    let selectable: Bool

    var displayName: String {
        localizedName.isEmpty ? sourceID : localizedName
    }
}

final class InputSourceManager {
    static let shared = InputSourceManager()

    func allSources() -> [InputSource] {
        guard let cfList = TISCreateInputSourceList(nil, false) else { return [] }
        let list = cfList.takeRetainedValue() as [AnyObject]
        var sources: [InputSource] = []
        for item in list {
            let ref = item as! TISInputSource
            guard let idValue = TISGetInputSourceProperty(ref, kTISPropertyInputSourceID) else { continue }
            let sourceID = stringValue(idValue) ?? ""
            if sourceID.isEmpty { continue }
            guard let typeValue = TISGetInputSourceProperty(ref, kTISPropertyInputSourceType) else { continue }
            let type = stringValue(typeValue) ?? ""
            if !isKeyboardType(type) { continue }
            let name = stringValue(TISGetInputSourceProperty(ref, kTISPropertyLocalizedName)) ?? sourceID
            let selectable = boolValue(TISGetInputSourceProperty(ref, kTISPropertyInputSourceIsSelectCapable))
            sources.append(InputSource(sourceID: sourceID, localizedName: name, selectable: selectable))
        }
        return sources
    }

    private func isKeyboardType(_ type: String) -> Bool {
        type == kTISTypeKeyboardLayout as String
            || type == kTISTypeKeyboardInputMethodWithoutModes as String
            || type == kTISTypeKeyboardInputMethodModeEnabled as String
            || type == kTISTypeKeyboardInputMode as String
    }

    func selectableSources() -> [InputSource] {
        allSources().filter { $0.selectable }
    }

    func currentSourceID() -> String? {
        guard let ref = TISCopyCurrentKeyboardInputSource() else { return nil }
        let input = ref.takeRetainedValue()
        guard let idValue = TISGetInputSourceProperty(input, kTISPropertyInputSourceID) else { return nil }
        return stringValue(idValue)
    }

    func currentSourceName() -> String? {
        guard let id = currentSourceID() else { return nil }
        return sourceName(for: id)
    }

    func sourceName(for sourceID: String) -> String? {
        allSources().first { $0.sourceID == sourceID }?.displayName
    }

    func sourceExists(sourceID: String) -> Bool {
        allSources().contains { $0.sourceID == sourceID }
    }

    func select(sourceID: String) -> Bool {
        guard let cfList = TISCreateInputSourceList(nil, false) else { return false }
        let list = cfList.takeRetainedValue() as [AnyObject]
        for item in list {
            let ref = item as! TISInputSource
            guard let idValue = TISGetInputSourceProperty(ref, kTISPropertyInputSourceID) else { continue }
            if stringValue(idValue) == sourceID {
                let status = TISSelectInputSource(ref)
                return status == noErr
            }
        }
        return false
    }

    private func stringValue(_ ptr: UnsafeRawPointer?) -> String? {
        guard let ptr else { return nil }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }

    private func boolValue(_ ptr: UnsafeRawPointer?) -> Bool {
        guard let ptr else { return false }
        return CFBooleanGetValue(unsafeBitCast(ptr, to: CFBoolean.self))
    }
}
