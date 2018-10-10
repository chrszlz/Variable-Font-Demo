//
//  ViewController.swift
//  V Fonts
//
//  Created by Chris Zelazo on 9/27/18.
//  Copyright © 2018 Z. All rights reserved.
//

/**
 
 // Sample Variable Font Attributes Dictionary
 
 Font:
 Inter UI
 
 Attribtues:
 {
     NSCTVariationAxisDefaultValue = 400;
     NSCTVariationAxisIdentifier = 2003265652;
     NSCTVariationAxisMaximumValue = 900;
     NSCTVariationAxisMinimumValue = 100;
     NSCTVariationAxisName = Weight;
 }
 {
     NSCTVariationAxisDefaultValue = 0;
     NSCTVariationAxisIdentifier = 1769234796;
     NSCTVariationAxisMaximumValue = 100;
     NSCTVariationAxisMinimumValue = 0;
     NSCTVariationAxisName = Italic;
 }
 
 */

import UIKit
import CoreText
import MediaPlayer

enum VariableFontAttribute: String, RawRepresentable {
    case name = "NSCTVariationAxisName"
    case identifier = "NSCTVariationAxisIdentifier"
    case defaultValue = "NSCTVariationAxisDefaultValue"
    case currentValue = "CZCTVariationAxisCurrentValue"
    case maxValue = "NSCTVariationAxisMaximumValue"
    case minValue = "NSCTVariationAxisMinimumValue"
}

// Mini struct to structure Variable Font axis data
class VariationAxis {
    var name: String
    var identifier: String
    var defaultValue: Double
    var currentValue: Double
    var minValue: Double
    var maxValue: Double
    
    var variationDirection: Int
    
    var minMaxDelta: Double {
        return maxValue - minValue
    }
    
    init(name: String, identifier: String, defaultValue: Double, currentValue: Double, minValue: Double, maxValue: Double) {
        self.name = name
        self.identifier = identifier
        self.defaultValue = defaultValue
        self.currentValue = currentValue
        self.minValue = minValue
        self.maxValue = maxValue
        
        self.variationDirection = 1
    }
    
    convenience init(attributes: [String: Any]) {
        let name = attributes[VariableFontAttribute.name.rawValue] as? String ?? "<no name>"
        let identifier = attributes[VariableFontAttribute.identifier.rawValue] as? String ?? "<no identifier>"
        let defaultValue = attributes[VariableFontAttribute.defaultValue.rawValue] as? Double ?? 0.0
        let currentValue = defaultValue // init `currentValue` with `defaultValue`
        let minValue = attributes[VariableFontAttribute.minValue.rawValue] as? Double ?? 0.0
        let maxValue = attributes[VariableFontAttribute.maxValue.rawValue] as? Double ?? 0.0
        self.init(name: name,
                  identifier: identifier,
                  defaultValue: defaultValue,
                  currentValue: currentValue,
                  minValue: minValue,
                  maxValue: maxValue)
    }
    
    func toggleVariationDirection() {
        variationDirection *= -1
    }
}

class ViewController: UIViewController {

    private let panRecognizer = UIPanGestureRecognizer()
    
    private var font: UIFont! {
        didSet {
            textView.font = font
        }
    }
    
    private var fontVariationAxes = [VariationAxis]()
    
    @IBOutlet weak var textView: UITextView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        textView.text = "Pack my box with five dozen liquor jugs."
        textView.layer.allowsEdgeAntialiasing = true
        textView.returnKeyType = .done
        textView.delegate = self
        
        font = UIFont(name: "Inter UI", size: 50)!
        let ctFont = CTFontCreateWithName(font.fontName as CFString, font.pointSize, nil)
        fontVariationAxes = (CTFontCopyVariationAxes(ctFont)! as Array).map { attributes in
            let attributesDict = attributes as? [String: Any] ?? [:]
            return VariationAxis(attributes: attributesDict)
        }
        
        panRecognizer.addTarget(self, action: #selector(handlePan(_:)))
        view.addGestureRecognizer(panRecognizer)
        
//        Timer.scheduledTimer(timeInterval: 0.002, target: self, selector: #selector(updateFontForTimer), userInfo: nil, repeats: true)
        
        // Prevents the volume HUD from showing
        let volumeView = MPVolumeView(frame: .zero)
        self.view.addSubview(volumeView)
        
        // Listen for System Volume changes
        let volumeChangedNotification = NSNotification.Name.init(rawValue: "AVSystemController_SystemVolumeDidChangeNotification")
        NotificationCenter.default.addObserver(self, selector: #selector(handleVolumeChanged(notification:)), name: volumeChangedNotification, object: nil)
    }
    
    @objc private func handleVolumeChanged(notification: Notification) {
        if let userInfo = notification.userInfo {
            if let volumeValue = userInfo["AVSystemController_AudioVolumeNotificationParameter"] as? Double {
                let weightAxis = fontVariationAxes[0]
                let value = (weightAxis.maxValue - weightAxis.minValue) * volumeValue
                
                scaleWeight(value: value)
                updateFont(with: fontVariationAxes)
            }
        }
    }
    
    private let variationStep: Int = 1
    @objc private func updateFontForTimer() {
        fontVariationAxes.forEach { axis in
            let increment = Double(variationStep * axis.variationDirection)
            axis.currentValue = max(axis.minValue, min(axis.maxValue, axis.currentValue + increment))
            
            if axis.currentValue == axis.minValue || axis.currentValue == axis.maxValue {
                axis.toggleVariationDirection()
            }
        }
        
        updateFont(with: fontVariationAxes)
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        let touchPoint = recognizer.location(in: view)
        let isBeginningTouch = recognizer.state == .began
        guard !isBeginningTouch || isBeginningTouch && textView.frame.contains(touchPoint) else {
            return
        }
        
        let panDistance = recognizer.translation(in: view)

        let scaleRect = textView.bounds
        
        let weightIncrement = Double(panDistance.x / scaleRect.width) * fontVariationAxes[0].minMaxDelta * 0.5
        scaleWeight(value: fontVariationAxes[0].currentValue + weightIncrement)
        
        let italicIncrement = Double(panDistance.y / scaleRect.height) * fontVariationAxes[1].minMaxDelta * 0.5
        scaleItalic(value: fontVariationAxes[1].currentValue + italicIncrement)
        
        // Update font
        updateFont(with: fontVariationAxes)
    }
    
    private func scaleWeight(value: Double) {
        let axis = fontVariationAxes[0]
        axis.currentValue = max(axis.minValue, min(axis.maxValue, value))
        fontVariationAxes[0] = axis
    }
    
    private func scaleItalic(value: Double) {
        let axis = fontVariationAxes[1]
        axis.currentValue = max(axis.minValue, min(axis.maxValue, value))
        fontVariationAxes[1] = axis
    }
    
    private func updateFont(with attributes: [VariationAxis]) {
        var attributesDict = [String: Any]()
        attributes.forEach {
            attributesDict[$0.name] = $0.currentValue
        }
        
        let fontDescriptor = UIFontDescriptor(fontAttributes: [UIFontDescriptor.AttributeName.name : font.fontName,
                                                               kCTFontVariationAttribute as UIFontDescriptor.AttributeName : attributesDict])
        font = UIFont(descriptor: fontDescriptor, size: font.pointSize)
    }

}

extension ViewController: UITextViewDelegate {
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard text != "\n" else {
            textView.resignFirstResponder()
            return false
        }
        return true
    }
    
}

