//
//  ExpyTableView.swift
//
//  Created by Okhan Okbay on 15/06/2017.
//
//  The MIT License (MIT)
//
//  Copyright (c) 2017 okhanokbay
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import UIKit

@objcMembers open class ExpyTableView: UITableView {
    
    fileprivate weak var expyDataSource: ExpyTableViewDataSource?
    fileprivate weak var expyDelegate: ExpyTableViewDelegate?
    private var sectionScroll: Int?
    private var scrollType: UITableView.ScrollPosition = .top
    
    public fileprivate(set) var expandedSections: [Int: Bool] = [:]
    
      open var expandingAnimation: UITableView.RowAnimation = ExpyTableViewDefaultValues.expandingAnimation
      open var collapsingAnimation: UITableView.RowAnimation = ExpyTableViewDefaultValues.collapsingAnimation
    
      public override init(frame: CGRect, style: UITableView.Style) {
        super.init(frame: frame, style: style)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    open override var dataSource: UITableViewDataSource? {
        
        get { return super.dataSource }
        
        set(dataSource) {
            guard let dataSource = dataSource else { return }
            expyDataSource = dataSource as? ExpyTableViewDataSource
            super.dataSource = self
        }
    }
    
    open override var delegate: UITableViewDelegate? {
        
        get { return super.delegate }
        
        set(delegate) {
            guard let delegate = delegate else { return }
            expyDelegate = delegate as? ExpyTableViewDelegate
            super.delegate = self
        }
    }
    
    open override func awakeFromNib() {
        super.awakeFromNib()
        if expyDelegate == nil {
            //Set UITableViewDelegate even if ExpyTableViewDelegate is nil. Because we are getting callbacks here in didSelectRowAtIndexPath UITableViewDelegate method.
            super.delegate = self
        }
    }
}

extension ExpyTableView {
    public func expand(_ section: Int, isScroll: Bool = false, scrollType: UITableView.ScrollPosition = .top) {
       
        if isScroll {
            self.scrollType = scrollType
            self.sectionScroll = section
        } else {
            self.sectionScroll = nil
        }
        animate(with: .expand, forSection: section, isScroll: isScroll)
    }
    
    public func collapse(_ section: Int) {
        animate(with: .collapse, forSection: section)
    }
    
    private func animate(with type: ExpyActionType, forSection section: Int, isScroll: Bool = true) {
        
    
        guard canExpand(section) else {
            if isScroll {
                checkScrollToIndexPath(indexPath: IndexPath(row: 0, section: section))
            }
            return
            
        }
        let sectionIsExpanded = didExpand(section)
        //If section is visible and action type is expand, OR, If section is not visible and action type is collapse, return.
        if ((type == .expand) && (sectionIsExpanded)) || ((type == .collapse) && (!sectionIsExpanded)) {
            if isScroll {
                checkScrollToIndexPath(indexPath: IndexPath(row: 0, section: section))
            }
            return
            
        }
        
        assign(section, asExpanded: (type == .expand))
        startAnimating(self, with: type, forSection: section, isScroll: isScroll)
    }
    
    
    func checkScrollToIndexPath(indexPath: IndexPath) {
        let rect = self.rectForRow(at: indexPath)
        DispatchQueue.main.async {
            if rect.origin.y > self.bounds.origin.y - 5, rect.origin.y < self.bounds.origin.y + 10 {
                // cell is top
            } else {
                self.scrollToRow(at: indexPath, at: .top, animated: true)
            }
        }

    }
    
    private func startAnimating(_ tableView: ExpyTableView, with type: ExpyActionType, forSection section: Int, isScroll: Bool = false) {
    
        let headerCell = (self.cellForRow(at: IndexPath(row: 0, section: section)))
        let headerCellConformant = headerCell as? ExpyTableViewHeaderCell
        
        CATransaction.begin()
        headerCell?.isUserInteractionEnabled = false
        
        //Inform the delegates here.
        headerCellConformant?.changeState((type == .expand ? .willExpand : .willCollapse), cellReuseStatus: false)
        expyDelegate?.tableView(tableView, expyState: (type == .expand ? .willExpand : .willCollapse), changeForSection: section)

        CATransaction.setCompletionBlock { [weak self] in
            guard let _self = self else {return}
            //Inform the delegates here.
            headerCellConformant?.changeState((type == .expand ? .didExpand : .didCollapse), cellReuseStatus: false)
            
            _self.expyDelegate?.tableView(tableView, expyState: (type == .expand ? .didExpand : .didCollapse), changeForSection: section)
            headerCell?.isUserInteractionEnabled = true
            if isScroll, type == .expand {
                _self.checkScrollToIndexPath(indexPath: IndexPath(row: 0, section: section))

            } else {
                let rect = tableView.rectForRow(at: IndexPath(row: 0, section: section))
                let tableViewMax = tableView.bounds.origin.y + tableView.frame.size.height - 100
                if rect.origin.y >= tableViewMax {
                    _self.scrollToRow(at: IndexPath(row: 0, section: section), at: _self.scrollType, animated: true)
                }
            }
        }
        
        self.beginUpdates()
        
        //Don't insert or delete anything if section has only 1 cell.
        if let sectionRowCount = expyDataSource?.tableView(tableView, numberOfRowsInSection: section), sectionRowCount > 1 {
            
            var indexesToProcess: [IndexPath] = []
            
            //Start from 1, because 0 is the header cell.
            for row in 1..<sectionRowCount {
                indexesToProcess.append(IndexPath(row: row, section: section))
            }
            
            //Expand means inserting rows, collapse means deleting rows.
            if type == .expand {
                self.insertRows(at: indexesToProcess, with: expandingAnimation)
            }else if type == .collapse {
                self.deleteRows(at: indexesToProcess, with: collapsingAnimation)
            }
        }
        self.endUpdates()

        
        CATransaction.commit()
    }
    
}

extension ExpyTableView: UITableViewDataSource {
    open func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let numberOfRows = expyDataSource?.tableView(self, numberOfRowsInSection: section) ?? 0
        
        guard canExpand(section) else { return numberOfRows }
        guard numberOfRows != 0 else { return 0 }
        
        return didExpand(section) ? numberOfRows : 1
    }
    
    open func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard canExpand(indexPath.section), indexPath.row == 0 else {
            return expyDataSource!.tableView(tableView, cellForRowAt: indexPath)
        }
        
        let headerCell = expyDataSource!.tableView(self, expandableCellForSection: indexPath.section)
        
        guard let headerCellConformant = headerCell as? ExpyTableViewHeaderCell else {
            return headerCell
        }
        
//        DispatchQueue.main.async {
//            if self.didExpand(indexPath.section) {
//                headerCellConformant.changeState(.willExpand, cellReuseStatus: true)
//                headerCellConformant.changeState(.didExpand, cellReuseStatus: true)
//            }else {
//                headerCellConformant.changeState(.willCollapse, cellReuseStatus: true)
//                headerCellConformant.changeState(.didCollapse, cellReuseStatus: true)
//            }
//        }
        return headerCell
    }
}

extension ExpyTableView: UITableViewDelegate {
    
    open func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        expyDelegate?.tableView?(tableView, didSelectRowAt: indexPath)
        guard canExpand(indexPath.section), indexPath.row == 0 else { return }
        didExpand(indexPath.section) ? collapse(indexPath.section) : expand(indexPath.section)
    }
}

//MARK: Helper Methods

extension ExpyTableView {
    fileprivate func canExpand(_ section: Int) -> Bool {
        //If canExpandSections delegate method is not implemented, it defaults to true.
        return expyDataSource?.tableView(self, canExpandSection: section) ?? ExpyTableViewDefaultValues.expandableStatus
    }
    
    fileprivate func didExpand(_ section: Int) -> Bool {
        return expandedSections[section] ?? false
    }
    
    fileprivate func assign(_ section: Int, asExpanded: Bool) {
        expandedSections[section] = asExpanded
    }
}

//MARK: Protocol Helper
extension ExpyTableView {
    fileprivate func verifyProtocol(_ aProtocol: Protocol, contains aSelector: Selector) -> Bool {
        return protocol_getMethodDescription(aProtocol, aSelector, true, true).name != nil || protocol_getMethodDescription(aProtocol, aSelector, false, true).name != nil
    }
    
    override open func responds(to aSelector: Selector!) -> Bool {
        if verifyProtocol(UITableViewDataSource.self, contains: aSelector) {
            return (super.responds(to: aSelector)) || (expyDataSource?.responds(to: aSelector) ?? false)
            
        }else if verifyProtocol(UITableViewDelegate.self, contains: aSelector) {
            return (super.responds(to: aSelector)) || (expyDelegate?.responds(to: aSelector) ?? false)
        }
        return super.responds(to: aSelector)
    }
    
    override open func forwardingTarget(for aSelector: Selector!) -> Any? {
        if verifyProtocol(UITableViewDataSource.self, contains: aSelector) {
            return expyDataSource
            
        }else if verifyProtocol(UITableViewDelegate.self, contains: aSelector) {
            return expyDelegate
        }
        return super.forwardingTarget(for: aSelector)
    }
}

