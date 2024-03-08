/*
 * Copyright © 2023-2024 Dustin Collins (Strega's Gate)
 * All Rights Reserved.
 *
 * http://stregasgate.com
 */

extension StackView {
    public enum Axis {
        case horizontal
        case vertical
    }
    public enum Distribution {
        case equalSpacing
    }
}

public final class StackView: View {
    public var axis: Axis {
        didSet {
            if axis != oldValue {
                self.setNeedsUpdateConstraints()
            }
        }
    }
    public var distribution: Distribution {
        didSet {
            if distribution != oldValue {
                self.setNeedsUpdateConstraints()
            }
        }
    }
    public var spacing: Float {
        didSet {
            if spacing != spacing {
                self.setNeedsUpdateConstraints()
            }
        }
    }
    
    public init(axis: Axis, distribution: Distribution, spacing: Float, subviews: [View]) {
        self.axis = axis
        self.distribution = distribution
        self.spacing = spacing
        super.init()
        for view in subviews {
            self.addSubview(view)
        }
        self.needsUpdateConstraints = true
    }
    
    public override func updateLayoutConstraints() {
        switch axis {
        case .horizontal:
            switch distribution {
            case .equalSpacing:
                var previousView: View = self
                for subView in subviews {
                    subView.layoutConstraints.removeAllVerticalPositionConstraints()
                    subView.layoutConstraints.removeAllHorizontalPositionConstraints()
                    if previousView === self {
                        subView.leadingAnchor.constrain(to: self.leadingAnchor)
                    }else{
                        subView.leadingAnchor.constrain(spacing, from: previousView.trailingAnchor)
                    }
                    subView.topAnchor.constrain(to: self.topAnchor)
                    subView.bottomAnchor.constrain(to: self.bottomAnchor)
                    previousView = subView
                }
                subviews.last?.trailingAnchor.constrain(to: self.trailingAnchor)
            }
        case .vertical:
            switch distribution {
            case .equalSpacing:
                var previousView: View = self
                for subView in subviews {
                    subView.layoutConstraints.removeAllVerticalPositionConstraints()
                    subView.layoutConstraints.removeAllHorizontalPositionConstraints()
                    if previousView === self {
                        subView.topAnchor.constrain(to: self.topAnchor)
                    }else{
                        subView.topAnchor.constrain(spacing, from: previousView.bottomAnchor)
                    }
                    subView.leadingAnchor.constrain(to: self.leadingAnchor)
                    subView.trailingAnchor.constrain(to: self.trailingAnchor)
                    previousView = subView
                }
                subviews.last?.bottomAnchor.constrain(to: self.bottomAnchor)
            }
        }
    }
}

