//
//  Extension.swift
//  ComputerVision
//
//  Created by hjliu on 2020/7/28.
//  Copyright © 2020 劉紘任. All rights reserved.
//

import UIKit

extension CGPoint {
  
  func scaled(to size: CGSize) -> CGPoint {
    return CGPoint(x: self.x * size.width,
                   y: self.y * size.height)
  }
}

extension String  {
  var isNumber: Bool {
    return !isEmpty && rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil
  }
}
