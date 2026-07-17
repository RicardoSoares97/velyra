#!/usr/bin/env swift
import Accelerate
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let fileManager = FileManager.default
let root = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
let projectMarkerURL = root.appendingPathComponent("project.yml")
let canonicalMarkURL = root.appendingPathComponent("docs/brand/velyra-mark.svg")
let sourceURL = root.appendingPathComponent("docs/brand/sources/onboarding-atmosphere-source.png")
let resourcesURL = root.appendingPathComponent("VelyraTV/Resources", isDirectory: true)
let finalCatalogURL = resourcesURL.appendingPathComponent("Assets.xcassets", isDirectory: true)
let stagingCatalogURL = resourcesURL.appendingPathComponent(
  "Assets.xcassets.staging", isDirectory: true)
let backupCatalogURL = resourcesURL.appendingPathComponent(
  "Assets.xcassets.backup", isDirectory: true)
let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
let orange = CGColor(
  red: CGFloat(0xDD) / 255, green: CGFloat(0x57) / 255, blue: CGFloat(0x1C) / 255, alpha: 1)

enum GeneratorError: Error, CustomStringConvertible {
  case cannotCreateContext(Int, Int)
  case cannotLoadImage(URL)
  case cannotWritePNG(URL)
  case invalidRepository(String)
  case invalidAlpha(URL, String)
  case invalidOwnedPath(URL)
  case injectedFailure
  case vImageFailure(String, vImage_Error)

  var description: String {
    switch self {
    case .cannotCreateContext(let width, let height):
      return "Cannot create \(width)x\(height) bitmap context"
    case .cannotLoadImage(let url): return "Cannot load image: \(url.path)"
    case .cannotWritePNG(let url): return "Cannot write PNG: \(url.path)"
    case .invalidRepository(let detail): return "Repository guard failed: \(detail)"
    case .invalidAlpha(let url, let detail): return "Invalid alpha in \(url.path): \(detail)"
    case .invalidOwnedPath(let url): return "Refusing to modify unowned path: \(url.path)"
    case .injectedFailure: return "Injected pre-publish failure"
    case .vImageFailure(let operation, let code):
      return "vImage \(operation) failed with code \(code)"
    }
  }
}

struct Raster {
  let scale: Int
  let width: Int
  let height: Int
}

enum BrandAssetKind {
  case iconStack
  case topShelf
}

struct BrandAssetSpec {
  let directory: String
  let role: String
  let logicalSize: String
  let filenameStem: String
  let rasters: [Raster]
  let kind: BrandAssetKind
}

let brandAssetSpecs = [
  BrandAssetSpec(
    directory: "App Icon - Small.imagestack",
    role: "primary-app-icon",
    logicalSize: "400x240",
    filenameStem: "app-icon-small",
    rasters: [
      Raster(scale: 1, width: 400, height: 240), Raster(scale: 2, width: 800, height: 480),
    ],
    kind: .iconStack
  ),
  BrandAssetSpec(
    directory: "App Icon - Large.imagestack",
    role: "primary-app-icon",
    logicalSize: "1280x768",
    filenameStem: "app-icon-large",
    rasters: [Raster(scale: 1, width: 1280, height: 768)],
    kind: .iconStack
  ),
  BrandAssetSpec(
    directory: "Top Shelf Image.imageset",
    role: "top-shelf-image",
    logicalSize: "1920x720",
    filenameStem: "top-shelf",
    rasters: [
      Raster(scale: 1, width: 1920, height: 720), Raster(scale: 2, width: 3840, height: 1440),
    ],
    kind: .topShelf
  ),
  BrandAssetSpec(
    directory: "Top Shelf Image Wide.imageset",
    role: "top-shelf-image-wide",
    logicalSize: "2320x720",
    filenameStem: "top-shelf-wide",
    rasters: [
      Raster(scale: 1, width: 2320, height: 720), Raster(scale: 2, width: 4640, height: 1440),
    ],
    kind: .topShelf
  ),
]

let info: [String: Any] = ["author": "xcode", "version": 1]

func makeDirectory(_ url: URL) throws {
  try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
}

func writeJSON(_ object: Any, to url: URL) throws {
  var data = try JSONSerialization.data(
    withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
  data.append(0x0A)
  try data.write(to: url, options: .atomic)
}

func requireRegularFile(_ url: URL) throws {
  var isDirectory: ObjCBool = false
  guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), !isDirectory.boolValue
  else {
    throw GeneratorError.invalidRepository("missing required file \(url.path)")
  }
}

func validateRepositoryRoot() throws {
  try requireRegularFile(projectMarkerURL)
  try requireRegularFile(canonicalMarkURL)
  try requireRegularFile(sourceURL)
  var isDirectory: ObjCBool = false
  guard fileManager.fileExists(atPath: resourcesURL.path, isDirectory: &isDirectory),
    isDirectory.boolValue
  else {
    throw GeneratorError.invalidRepository("missing resources directory \(resourcesURL.path)")
  }
}

func assertOwnedCatalogPath(_ url: URL) throws {
  let allowed = Set(
    [finalCatalogURL, stagingCatalogURL, backupCatalogURL].map { $0.standardizedFileURL.path })
  guard allowed.contains(url.standardizedFileURL.path),
    url.deletingLastPathComponent().standardizedFileURL == resourcesURL.standardizedFileURL
  else {
    throw GeneratorError.invalidOwnedPath(url)
  }
}

func removeOwnedItemIfPresent(_ url: URL) throws {
  try assertOwnedCatalogPath(url)
  if fileManager.fileExists(atPath: url.path) {
    try fileManager.removeItem(at: url)
  }
}

func recoverInterruptedPublish() throws {
  try assertOwnedCatalogPath(finalCatalogURL)
  try assertOwnedCatalogPath(backupCatalogURL)
  let hasFinal = fileManager.fileExists(atPath: finalCatalogURL.path)
  let hasBackup = fileManager.fileExists(atPath: backupCatalogURL.path)
  if !hasFinal && hasBackup {
    try fileManager.moveItem(at: backupCatalogURL, to: finalCatalogURL)
  } else if hasFinal && hasBackup {
    try removeOwnedItemIfPresent(backupCatalogURL)
  }
}

func publishStagedCatalog() throws {
  try assertOwnedCatalogPath(stagingCatalogURL)
  try assertOwnedCatalogPath(finalCatalogURL)
  try assertOwnedCatalogPath(backupCatalogURL)
  if fileManager.fileExists(atPath: finalCatalogURL.path) {
    try fileManager.moveItem(at: finalCatalogURL, to: backupCatalogURL)
  }
  do {
    try fileManager.moveItem(at: stagingCatalogURL, to: finalCatalogURL)
    try removeOwnedItemIfPresent(backupCatalogURL)
  } catch {
    if !fileManager.fileExists(atPath: finalCatalogURL.path),
      fileManager.fileExists(atPath: backupCatalogURL.path)
    {
      try? fileManager.moveItem(at: backupCatalogURL, to: finalCatalogURL)
    }
    throw error
  }
}

func makeContext(width: Int, height: Int, opaque: Bool) throws -> CGContext {
  guard
    let context = CGContext(
      data: nil,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: width * 4,
      space: sRGB,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
    )
  else {
    throw GeneratorError.cannotCreateContext(width, height)
  }

  context.translateBy(x: 0, y: CGFloat(height))
  context.scaleBy(x: 1, y: -1)
  context.setAllowsAntialiasing(true)
  context.setShouldAntialias(true)
  context.interpolationQuality = .high
  let canvas = CGRect(x: 0, y: 0, width: width, height: height)
  context.clear(canvas)
  if opaque {
    context.setFillColor(CGColor(red: 5 / 255, green: 5 / 255, blue: 7 / 255, alpha: 1))
    context.fill(canvas)
  }
  return context
}

func writePNG(_ context: CGContext, to url: URL) throws {
  guard
    let image = context.makeImage(),
    let destination = CGImageDestinationCreateWithURL(
      url as CFURL, UTType.png.identifier as CFString, 1, nil)
  else {
    throw GeneratorError.cannotWritePNG(url)
  }
  let properties: [CFString: Any] = [
    kCGImagePropertyColorModel: kCGImagePropertyColorModelRGB,
    kCGImagePropertyDepth: 8,
    kCGImagePropertyPNGDictionary: [kCGImagePropertyPNGInterlaceType: 0],
  ]
  CGImageDestinationAddImage(destination, image, properties as CFDictionary)
  guard CGImageDestinationFinalize(destination) else {
    throw GeneratorError.cannotWritePNG(url)
  }
}

func validateAlpha(_ context: CGContext, at url: URL, mustBeOpaque: Bool) throws {
  guard
    let image = context.makeImage(),
    let data = image.dataProvider?.data,
    let bytes = CFDataGetBytePtr(data)
  else {
    throw GeneratorError.cannotWritePNG(url)
  }
  var containsTransparency = false
  var containsVisiblePixels = false
  for y in 0..<image.height {
    for x in 0..<image.width {
      let alpha = bytes[y * image.bytesPerRow + x * 4 + 3]
      if alpha > 0 {
        containsVisiblePixels = true
      }
      if alpha < 255 {
        if mustBeOpaque {
          throw GeneratorError.invalidAlpha(url, "expected alpha 255 for every pixel")
        }
        containsTransparency = true
      }
    }
  }
  if !mustBeOpaque && (!containsTransparency || !containsVisiblePixels) {
    throw GeneratorError.invalidAlpha(url, "expected both transparent and visible pixels")
  }
}

func ribbonPath(in destination: CGRect) -> (ribbon: CGPath, facet: CGPath, bounds: CGRect) {
  let scale = min(destination.width / 110, destination.height / 120)
  let origin = CGPoint(
    x: destination.midX - 55 * scale,
    y: destination.midY - 60 * scale
  )
  func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
    CGPoint(x: origin.x + x * scale, y: origin.y + y * scale)
  }

  let ribbon = CGMutablePath()
  ribbon.move(to: point(10, 16))
  ribbon.addLine(to: point(49, 104))
  ribbon.addCurve(to: point(61, 104), control1: point(51, 109), control2: point(58, 109))
  ribbon.addLine(to: point(100, 16))
  ribbon.addLine(to: point(77, 16))
  ribbon.addLine(to: point(55, 72))
  ribbon.addLine(to: point(33, 16))
  ribbon.closeSubpath()

  let facet = CGMutablePath()
  facet.move(to: point(33, 16))
  facet.addLine(to: point(58, 16))
  facet.addLine(to: point(45, 48))
  facet.closeSubpath()

  return (ribbon, facet, CGRect(x: origin.x, y: origin.y, width: 110 * scale, height: 120 * scale))
}

func drawRibbon(in context: CGContext, destination: CGRect) {
  let paths = ribbonPath(in: destination)
  let gradient = CGGradient(
    colorsSpace: sRGB,
    colors: [
      CGColor(red: 1, green: CGFloat(0x9B) / 255, blue: CGFloat(0x60) / 255, alpha: 1),
      CGColor(
        red: CGFloat(0xC8) / 255, green: CGFloat(0x37) / 255, blue: CGFloat(0x0D) / 255, alpha: 1),
    ] as CFArray,
    locations: [0, 1]
  )!
  context.saveGState()
  context.addPath(paths.ribbon)
  context.clip()
  context.drawLinearGradient(
    gradient,
    start: CGPoint(x: paths.bounds.minX, y: paths.bounds.minY),
    end: CGPoint(x: paths.bounds.maxX, y: paths.bounds.maxY),
    options: []
  )
  context.restoreGState()
  context.setFillColor(
    CGColor(red: 1, green: CGFloat(0xE0) / 255, blue: CGFloat(0xCC) / 255, alpha: 0.85))
  context.addPath(paths.facet)
  context.fillPath()
}

func drawIconBackground(in context: CGContext, width: Int, height: Int) {
  let canvas = CGRect(x: 0, y: 0, width: width, height: height)
  context.setFillColor(CGColor(red: 5 / 255, green: 5 / 255, blue: 7 / 255, alpha: 1))
  context.fill(canvas)
  let glow = CGGradient(
    colorsSpace: sRGB,
    colors: [
      CGColor(
        red: CGFloat(0xDD) / 255, green: CGFloat(0x57) / 255, blue: CGFloat(0x1C) / 255, alpha: 0.34
      ),
      CGColor(
        red: CGFloat(0x48) / 255, green: CGFloat(0x16) / 255, blue: CGFloat(0x09) / 255, alpha: 0.12
      ),
      CGColor(red: 0, green: 0, blue: 0, alpha: 0),
    ] as CFArray,
    locations: [0, 0.42, 1]
  )!
  let radius = hypot(CGFloat(width), CGFloat(height)) * 0.72
  context.drawRadialGradient(
    glow,
    startCenter: CGPoint(x: CGFloat(width) * 0.82, y: CGFloat(height) * 0.18),
    startRadius: 0,
    endCenter: CGPoint(x: CGFloat(width) * 0.82, y: CGFloat(height) * 0.18),
    endRadius: radius,
    options: [.drawsAfterEndLocation]
  )
}

func drawIconLight(in context: CGContext, width: Int, height: Int) {
  let w = CGFloat(width)
  let h = CGFloat(height)
  let band = CGMutablePath()
  band.move(to: CGPoint(x: w * 0.48, y: 0))
  band.addLine(to: CGPoint(x: w, y: 0))
  band.addLine(to: CGPoint(x: w, y: h * 0.38))
  band.addLine(to: CGPoint(x: w * 0.20, y: h))
  band.addLine(to: CGPoint(x: 0, y: h))
  band.addLine(to: CGPoint(x: 0, y: h * 0.82))
  band.closeSubpath()
  let light = CGGradient(
    colorsSpace: sRGB,
    colors: [
      CGColor(
        red: CGFloat(0xDD) / 255, green: CGFloat(0x57) / 255, blue: CGFloat(0x1C) / 255, alpha: 0),
      CGColor(red: 1, green: CGFloat(0x78) / 255, blue: CGFloat(0x30) / 255, alpha: 0.30),
      CGColor(
        red: CGFloat(0xDD) / 255, green: CGFloat(0x57) / 255, blue: CGFloat(0x1C) / 255, alpha: 0),
    ] as CFArray,
    locations: [0, 0.56, 1]
  )!
  context.saveGState()
  context.addPath(band)
  context.clip()
  context.drawLinearGradient(
    light,
    start: CGPoint(x: 0, y: h),
    end: CGPoint(x: w, y: 0),
    options: []
  )
  context.restoreGState()
}

func loadImage(_ url: URL) throws -> CGImage {
  guard
    let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
    let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
  else {
    throw GeneratorError.cannotLoadImage(url)
  }
  return image
}

func aspectFillImage(_ image: CGImage, width: Int, height: Int) throws -> CGImage {
  let sourceContext = try makeContext(width: image.width, height: image.height, opaque: true)
  sourceContext.interpolationQuality = .none
  sourceContext.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
  guard
    let normalized = sourceContext.makeImage(),
    let sourceData = normalized.dataProvider?.data,
    let sourceBytes = CFDataGetBytePtr(sourceData)
  else {
    throw GeneratorError.cannotLoadImage(sourceURL)
  }

  let sourceWidth = normalized.width
  let sourceHeight = normalized.height
  let targetAspect = Double(width) / Double(height)
  let sourceAspect = Double(sourceWidth) / Double(sourceHeight)
  var cropWidth = sourceWidth
  var cropHeight = sourceHeight
  if sourceAspect > targetAspect {
    cropWidth = min(sourceWidth, max(1, Int((Double(sourceHeight) * targetAspect).rounded())))
  } else if sourceAspect < targetAspect {
    cropHeight = min(sourceHeight, max(1, Int((Double(sourceWidth) / targetAspect).rounded())))
  }
  let cropX = (sourceWidth - cropWidth) / 2
  let cropY = (sourceHeight - cropHeight) / 2
  let cropOffset = cropY * normalized.bytesPerRow + cropX * 4
  var sourceBuffer = vImage_Buffer(
    data: UnsafeMutableRawPointer(mutating: sourceBytes.advanced(by: cropOffset)),
    height: vImagePixelCount(cropHeight),
    width: vImagePixelCount(cropWidth),
    rowBytes: normalized.bytesPerRow
  )
  var destinationBuffer = vImage_Buffer()
  let initializationError = vImageBuffer_Init(
    &destinationBuffer,
    vImagePixelCount(height),
    vImagePixelCount(width),
    32,
    vImage_Flags(kvImageNoFlags)
  )
  guard initializationError == kvImageNoError else {
    throw GeneratorError.vImageFailure("destination allocation", initializationError)
  }
  defer { free(destinationBuffer.data) }
  let scaleError = vImageScale_ARGB8888(
    &sourceBuffer,
    &destinationBuffer,
    nil,
    vImage_Flags(kvImageHighQualityResampling | kvImageDoNotTile)
  )
  guard scaleError == kvImageNoError else {
    throw GeneratorError.vImageFailure("high-quality aspect-fill", scaleError)
  }

  let data =
    Data(
      bytes: destinationBuffer.data,
      count: destinationBuffer.rowBytes * height
    ) as CFData
  guard
    let provider = CGDataProvider(data: data),
    let result = CGImage(
      width: width,
      height: height,
      bitsPerComponent: 8,
      bitsPerPixel: 32,
      bytesPerRow: destinationBuffer.rowBytes,
      space: sRGB,
      bitmapInfo: CGBitmapInfo(
        rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
      ),
      provider: provider,
      decode: nil,
      shouldInterpolate: false,
      intent: .defaultIntent
    )
  else {
    throw GeneratorError.cannotCreateContext(width, height)
  }
  return result
}

func drawAspectFill(_ image: CGImage, in context: CGContext, width: Int, height: Int) throws {
  let scaledImage = try aspectFillImage(image, width: width, height: height)
  context.saveGState()
  context.interpolationQuality = .none
  context.draw(scaledImage, in: CGRect(x: 0, y: 0, width: width, height: height))
  context.restoreGState()
}

func renderIconLayer(role: String, raster: Raster, to url: URL) throws {
  let isBackground = role == "Background"
  let context = try makeContext(width: raster.width, height: raster.height, opaque: isBackground)
  switch role {
  case "Background":
    drawIconBackground(in: context, width: raster.width, height: raster.height)
  case "Light":
    drawIconLight(in: context, width: raster.width, height: raster.height)
  case "Mark":
    let safe = CGRect(
      x: CGFloat(raster.width) * 0.16,
      y: CGFloat(raster.height) * 0.16,
      width: CGFloat(raster.width) * 0.68,
      height: CGFloat(raster.height) * 0.68
    )
    drawRibbon(in: context, destination: safe)
  default:
    fatalError("Unknown icon role: \(role)")
  }
  try validateAlpha(context, at: url, mustBeOpaque: isBackground)
  try writePNG(context, to: url)
}

func rasterFilename(for spec: BrandAssetSpec, raster: Raster, iconRole: String? = nil) -> String {
  let stem = iconRole?.lowercased() ?? spec.filenameStem
  return "\(stem)-\(raster.width)x\(raster.height).png"
}

func generateIconStack(_ spec: BrandAssetSpec, in brandURL: URL) throws {
  let stackURL = brandURL.appendingPathComponent(spec.directory, isDirectory: true)
  try makeDirectory(stackURL)
  let roles = ["Mark", "Light", "Background"]
  try writeJSON(
    ["info": info, "layers": roles.map { ["filename": "\($0).imagestacklayer"] }],
    to: stackURL.appendingPathComponent("Contents.json")
  )

  for role in roles {
    let layerURL = stackURL.appendingPathComponent("\(role).imagestacklayer", isDirectory: true)
    let imageSetURL = layerURL.appendingPathComponent("\(role).imageset", isDirectory: true)
    try makeDirectory(imageSetURL)
    try writeJSON(["info": info], to: layerURL.appendingPathComponent("Contents.json"))
    var images: [[String: Any]] = []
    for raster in spec.rasters {
      let filename = rasterFilename(for: spec, raster: raster, iconRole: role)
      try renderIconLayer(
        role: role, raster: raster, to: imageSetURL.appendingPathComponent(filename))
      images.append(["filename": filename, "idiom": "tv", "scale": "\(raster.scale)x"])
    }
    try writeJSON(
      ["images": images, "info": info], to: imageSetURL.appendingPathComponent("Contents.json"))
  }
}

func drawTopShelfBackground(in context: CGContext, width: Int, height: Int) {
  let canvas = CGRect(x: 0, y: 0, width: width, height: height)
  context.setFillColor(CGColor(red: 3 / 255, green: 3 / 255, blue: 5 / 255, alpha: 1))
  context.fill(canvas)

  let edgeLight = CGGradient(
    colorsSpace: sRGB,
    colors: [
      CGColor(
        red: CGFloat(0xDD) / 255,
        green: CGFloat(0x57) / 255,
        blue: CGFloat(0x1C) / 255,
        alpha: 0.22
      ),
      CGColor(
        red: CGFloat(0x74) / 255,
        green: CGFloat(0x22) / 255,
        blue: CGFloat(0x0A) / 255,
        alpha: 0.07
      ),
      CGColor(red: 0, green: 0, blue: 0, alpha: 0),
    ] as CFArray,
    locations: [0, 0.38, 1]
  )!
  let center = CGPoint(x: CGFloat(width) * 0.08, y: CGFloat(height) * 0.5)
  context.drawRadialGradient(
    edgeLight,
    startCenter: center,
    startRadius: 0,
    endCenter: center,
    endRadius: CGFloat(width) * 0.46,
    options: [.drawsAfterEndLocation]
  )

  context.saveGState()
  context.setStrokeColor(orange.copy(alpha: 0.11)!)
  context.setLineWidth(CGFloat(height) * 0.012)
  context.setLineCap(.round)
  let ribbonLight = CGMutablePath()
  ribbonLight.move(to: CGPoint(x: CGFloat(width) * 0.76, y: -CGFloat(height) * 0.08))
  ribbonLight.addCurve(
    to: CGPoint(x: CGFloat(width) * 1.03, y: CGFloat(height) * 0.92),
    control1: CGPoint(x: CGFloat(width) * 0.84, y: CGFloat(height) * 0.18),
    control2: CGPoint(x: CGFloat(width) * 0.90, y: CGFloat(height) * 0.72)
  )
  context.addPath(ribbonLight)
  context.strokePath()
  context.restoreGState()
}

func generateTopShelf(_ spec: BrandAssetSpec, in brandURL: URL) throws {
  let imageSetURL = brandURL.appendingPathComponent(spec.directory, isDirectory: true)
  try makeDirectory(imageSetURL)
  var images: [[String: Any]] = []
  for raster in spec.rasters {
    let filename = rasterFilename(for: spec, raster: raster)
    let context = try makeContext(width: raster.width, height: raster.height, opaque: true)
    drawTopShelfBackground(in: context, width: raster.width, height: raster.height)
    let markBox = CGRect(
      x: CGFloat(raster.width) * 0.075,
      y: CGFloat(raster.height) * 0.24,
      width: CGFloat(raster.width) * 0.13,
      height: CGFloat(raster.height) * 0.52
    )
    drawRibbon(in: context, destination: markBox)
    let outputURL = imageSetURL.appendingPathComponent(filename)
    try validateAlpha(context, at: outputURL, mustBeOpaque: true)
    try writePNG(context, to: outputURL)
    images.append(["filename": filename, "idiom": "tv", "scale": "\(raster.scale)x"])
  }
  try writeJSON(
    ["images": images, "info": info], to: imageSetURL.appendingPathComponent("Contents.json"))
}

func generateCatalog(at catalogURL: URL) throws {
  try makeDirectory(catalogURL)
  let source = try loadImage(sourceURL)
  let brandURL = catalogURL.appendingPathComponent("AppIcon.brandassets", isDirectory: true)
  try makeDirectory(brandURL)
  for spec in brandAssetSpecs {
    switch spec.kind {
    case .iconStack:
      try generateIconStack(spec, in: brandURL)
    case .topShelf:
      try generateTopShelf(spec, in: brandURL)
    }
  }
  let brandAssets: [[String: Any]] = brandAssetSpecs.map {
    ["filename": $0.directory, "idiom": "tv", "role": $0.role, "size": $0.logicalSize]
  }
  try writeJSON(
    ["assets": brandAssets, "info": info], to: brandURL.appendingPathComponent("Contents.json"))

  let onboardingURL = catalogURL.appendingPathComponent(
    "OnboardingFallback.imageset", isDirectory: true)
  try makeDirectory(onboardingURL)
  let onboardingFilename = "onboarding-fallback-4k.png"
  let onboarding = try makeContext(width: 3840, height: 2160, opaque: true)
  try drawAspectFill(source, in: onboarding, width: 3840, height: 2160)
  let onboardingOutputURL = onboardingURL.appendingPathComponent(onboardingFilename)
  try validateAlpha(onboarding, at: onboardingOutputURL, mustBeOpaque: true)
  try writePNG(onboarding, to: onboardingOutputURL)
  try writeJSON(
    [
      "images": [["filename": onboardingFilename, "idiom": "universal", "scale": "1x"]],
      "info": info,
    ],
    to: onboardingURL.appendingPathComponent("Contents.json")
  )

  let markURL = catalogURL.appendingPathComponent("VelyraMark.imageset", isDirectory: true)
  try makeDirectory(markURL)
  let markFilename = "velyra-mark-1024x1024.png"
  let mark = try makeContext(width: 1024, height: 1024, opaque: false)
  drawRibbon(
    in: mark,
    destination: CGRect(x: 153.6, y: 153.6, width: 716.8, height: 716.8)
  )
  let markOutputURL = markURL.appendingPathComponent(markFilename)
  try validateAlpha(mark, at: markOutputURL, mustBeOpaque: false)
  try writePNG(mark, to: markOutputURL)
  try writeJSON(
    ["images": [["filename": markFilename, "idiom": "universal", "scale": "1x"]], "info": info],
    to: markURL.appendingPathComponent("Contents.json")
  )

  try writeJSON(["info": info], to: catalogURL.appendingPathComponent("Contents.json"))
}

func run() throws {
  try validateRepositoryRoot()
  try recoverInterruptedPublish()
  try removeOwnedItemIfPresent(stagingCatalogURL)
  do {
    try generateCatalog(at: stagingCatalogURL)
    if ProcessInfo.processInfo.environment["VELYRA_BRAND_FAIL_BEFORE_PUBLISH"] == "1" {
      throw GeneratorError.injectedFailure
    }
    try publishStagedCatalog()
  } catch {
    try? removeOwnedItemIfPresent(stagingCatalogURL)
    throw error
  }
  print("Generated Velyra brand assets at \(finalCatalogURL.path)")
}

do {
  try run()
} catch {
  fputs("generate_brand_assets.swift: \(error)\n", stderr)
  exit(1)
}
