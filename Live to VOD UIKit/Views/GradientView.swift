//
//  GradientView.swift
//  Live to VOD UIKit
//
//  Created by Uldis Zingis on 23/02/2022.
//

import Foundation
import QuartzCore
import UIKit

class GradientView: UIView {
    override open class var layerClass: AnyClass {
        return CAGradientLayer.classForCoder()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        let gradientLayer = layer as! CAGradientLayer
        gradientLayer.colors = [UIColor.clear.cgColor, UIColor.black.cgColor]
    }
}
