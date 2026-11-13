// Development tool for the visuals. See AGENTS.md.
import Foundation
import PrettyDrawKit

let arguments = Array(CommandLine.arguments.dropFirst())
let usage = "usage: pretty-draw-render gallery <dir> | icon <dir.iconset>"

func path(at index: Int) -> URL {
    guard arguments.indices.contains(index) else { fatalError(usage) }
    return URL(fileURLWithPath: arguments[index])
}

switch arguments.first {
case "gallery":
    let directory = path(at: 1)
    try DevTools.renderSmoothing(to: directory)
    try DevTools.renderStyles(to: directory)
    try MainActor.assumeIsolated { try DevTools.renderInterface(to: directory) }
    try DevTools.renderIcon(to: directory)
case "icon":
    try DevTools.renderIconSet(to: path(at: 1))
default:
    fatalError(usage)
}
