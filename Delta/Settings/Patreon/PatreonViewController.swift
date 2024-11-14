//
//  PatreonViewController.swift
//  AltStore
//
//  Created by Riley Testut on 9/5/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit

import Roxas

@available(iOS 17.5, *)
extension PatreonViewController
{
    private enum Section: Int, CaseIterable
    {
        case about
        case patrons
    }
}

@available(iOS 17.5, *)
class PatreonViewController: UICollectionViewController
{
    private lazy var dataSource = self.makeDataSource()
    private lazy var patronsDataSource = self.makePatronsDataSource()
    
    private var prototypeAboutHeader: AboutPatreonHeaderView!
        
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        let aboutHeaderNib = UINib(nibName: "AboutPatreonHeaderView", bundle: nil)
        self.prototypeAboutHeader = aboutHeaderNib.instantiate(withOwner: nil, options: nil)[0] as? AboutPatreonHeaderView
        
        self.collectionView.dataSource = self.dataSource
        
        self.collectionView.register(aboutHeaderNib, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "AboutHeader")
        self.collectionView.register(PatronsHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "PatronsHeader")
        self.collectionView.register(PatronsFooterView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "PatronsFooter")
        
        NotificationCenter.default.addObserver(self, selector: #selector(PatreonViewController.didUpdatePatrons(_:)), name: FriendZoneManager.didUpdatePatronsNotification, object: nil)
        
        self.update()
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        self.fetchPatrons()
        
        self.update()
    }
    
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        
        let layout = self.collectionViewLayout as! UICollectionViewFlowLayout
        
        var itemWidth = (self.collectionView.bounds.width - (layout.sectionInset.left + layout.sectionInset.right + layout.minimumInteritemSpacing)) / 2
        itemWidth.round(.down)
        
        layout.itemSize = CGSize(width: itemWidth, height: layout.itemSize.height)
    }
}

@available(iOS 17.5, *)
private extension PatreonViewController
{
    func makeDataSource() -> RSTCompositeCollectionViewDataSource<ManagedPatron>
    {
        let aboutDataSource = RSTDynamicCollectionViewDataSource<ManagedPatron>()
        aboutDataSource.numberOfSectionsHandler = { 1 }
        aboutDataSource.numberOfItemsHandler = { _ in 0 }
        
        let dataSource = RSTCompositeCollectionViewDataSource<ManagedPatron>(dataSources: [aboutDataSource, self.patronsDataSource])
        dataSource.proxy = self
        return dataSource
    }
    
    func makePatronsDataSource() -> RSTFetchedResultsCollectionViewDataSource<ManagedPatron>
    {
        let fetchRequest: NSFetchRequest<ManagedPatron> = ManagedPatron.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K != nil", #keyPath(ManagedPatron.name)) // No use displaying patrons with nil names.
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(ManagedPatron.name), ascending: true, selector: #selector(NSString.caseInsensitiveCompare(_:)))]
        
        let patronsDataSource = RSTFetchedResultsCollectionViewDataSource<ManagedPatron>(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.shared.viewContext)
        patronsDataSource.cellConfigurationHandler = { (cell, patron, indexPath) in
            let cell = cell as! PatronCollectionViewCell
            cell.textLabel.text = patron.name
        }
        
        return patronsDataSource
    }
    
    func update()
    {
        self.collectionView.reloadData()
    }
    
    func prepare(_ headerView: AboutPatreonHeaderView)
    {
        headerView.layoutMargins = self.view.layoutMargins
        headerView.tintColor = .deltaPurple
        
        var donateText = AttributedString(localized: "Become Friend Zone Patron")
        donateText.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        
        var priceText = AttributedString(localized: "$12.99 / month")
        priceText.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = 1.2
        
        let container = AttributeContainer([.paragraphStyle: paragraphStyle]) // Necessary to silence "NSParagraphStyle not Sendable" warning
        var attributedText = donateText + "\n" + priceText
        attributedText = attributedText.mergingAttributes(container, mergePolicy: .keepNew)
        
        headerView.supportButton.titleLabel?.numberOfLines = 0
        headerView.supportButton.setAttributedTitle(NSAttributedString(attributedText), for: .normal)
        
        headerView.supportButton.addTarget(self, action: #selector(PatreonViewController.becomeFriendZonePatron), for: .primaryActionTriggered)
        headerView.restorePurchaseButton.addTarget(self, action: #selector(PatreonViewController.restorePurchase), for: .primaryActionTriggered)
    }
}

@available(iOS 17.5, *)
private extension PatreonViewController
{
    @objc func fetchPatrons()
    {
        // User explicitly navigated to this screen, so allow fetching friend zone patrons.
        UserDefaults.standard.shouldFetchFriendZonePatrons = true
        
        FriendZoneManager.shared.updatePatronsIfNeeded()
        self.update()
    }
    
    @objc func didUpdatePatrons(_ notification: Notification)
    {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Wait short delay before reloading or else footer won't properly update if it's already visible 🤷‍♂️
            self.collectionView.reloadData()
        }
    }
    
    @objc func becomeFriendZonePatron()
    {
        Task<Void, Never> {
            do
            {
                try await RevenueCatManager.shared.purchaseFriendZoneSubscription()
            }
            catch is CancellationError
            {
                // Ignore
            }
            catch
            {
                let alertController = UIAlertController(title: NSLocalizedString("Unable to Purchase Friend Zone Subscription", comment: ""), error: error)
                self.present(alertController, animated: true)
            }
        }
    }
    
    @objc func restorePurchase()
    {
        Task<Void, Never> {
            do
            {
                try await RevenueCatManager.shared.requestRestorePurchases()
            }
            catch is CancellationError
            {
                // Ignore
            }
            catch
            {
                let alertController = UIAlertController(title: NSLocalizedString("Unable to Restore Purchase", comment: ""), error: error)
                self.present(alertController, animated: true)
            }
        }
    }
}

@available(iOS 17.5, *)
extension PatreonViewController
{
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView
    {
        let section = Section.allCases[indexPath.section]
        switch section
        {
        case .about:
            let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "AboutHeader", for: indexPath) as! AboutPatreonHeaderView
            self.prepare(headerView)
            return headerView
            
        case .patrons:
            if kind == UICollectionView.elementKindSectionHeader
            {
                let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "PatronsHeader", for: indexPath) as! PatronsHeaderView
                headerView.textLabel.text = NSLocalizedString("Special thanks to…", comment: "")
                return headerView
            }
            else
            {
                let footerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "PatronsFooter", for: indexPath) as! PatronsFooterView
                footerView.button.isIndicatingActivity = false
                footerView.button.isHidden = false
                footerView.button.addTarget(self, action: #selector(PatreonViewController.fetchPatrons), for: .primaryActionTriggered)
                footerView.button.activityIndicatorView.color = .secondaryLabel
                footerView.button.setTitleColor(.secondaryLabel, for: .normal)
                
                switch FriendZoneManager.shared.updatePatronsResult
                {
                case .none: footerView.button.isIndicatingActivity = true
                case .success?: footerView.button.isHidden = true
                case .failure?:
                    #if DEBUG
                    let debug = true
                    #else
                    let debug = false
                    #endif
                    
                    if self.patronsDataSource.itemCount == 0 || debug
                    {
                        // Only show error message if there aren't any cached Patrons (or if this is a debug build).
                        
                        footerView.button.isHidden = false
                        footerView.button.setTitle(NSLocalizedString("Error Loading Patrons", comment: ""), for: .normal)
                    }
                    else
                    {
                        footerView.button.isHidden = true
                    }
                }
                
                return footerView
            }
        }
    }
}

@available(iOS 17.5, *)
extension PatreonViewController: UICollectionViewDelegateFlowLayout
{
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize
    {
        let section = Section.allCases[section]
        switch section
        {
        case .about:
            let widthConstraint = self.prototypeAboutHeader.widthAnchor.constraint(equalToConstant: collectionView.bounds.width)
            NSLayoutConstraint.activate([widthConstraint])
            defer { NSLayoutConstraint.deactivate([widthConstraint]) }
            
            self.prepare(self.prototypeAboutHeader)
            
            let size = self.prototypeAboutHeader.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
            return size
            
        case .patrons:
            return CGSize(width: 320, height: 20)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize
    {
        let section = Section.allCases[section]
        switch section
        {
        case .about: return .zero
        case .patrons: return CGSize(width: 320, height: 44)
        }
    }
}