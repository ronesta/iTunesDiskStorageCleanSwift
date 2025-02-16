//
//  ViewController.swift
//  iTunesDiskStorageCleanSwift
//
//  Created by Ибрагим Габибли on 11.02.2025.
//

import UIKit
import SnapKit

final class SearchViewController: UIViewController {
    let searchBar: UISearchBar = {
        let searchBar = UISearchBar()
        searchBar.searchBarStyle = .minimal
        searchBar.placeholder = "Search Albums"
        searchBar.sizeToFit()
        return searchBar
    }()

    private let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: UIScreen.main.bounds.width - 15, height: 130)
        layout.minimumLineSpacing = 7
        layout.minimumInteritemSpacing = 0
        layout.sectionInset = UIEdgeInsets.zero

        let collectionView = UICollectionView(frame: .zero,
                                              collectionViewLayout: layout
        )
        collectionView.backgroundColor = .clear
        collectionView.register(
            AlbumCollectionViewCell.self,
            forCellWithReuseIdentifier: AlbumCollectionViewCell.id
        )

        return collectionView
    }()

    var albums = [Album]()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
    }

    private func setupViews() {
        view.backgroundColor = .systemGray6
        view.addSubview(searchBar)
        view.addSubview(collectionView)
        navigationItem.titleView = searchBar

        searchBar.delegate = self
        collectionView.dataSource = self
        collectionView.delegate = self

        collectionView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.bottom.equalTo(view.safeAreaLayoutGuide)
            make.horizontalEdges.equalToSuperview()
        }
    }

    func searchAlbums(with term: String) {
        let savedAlbums = DiskStorageManager.shared.loadAlbums(for: term)
        if !savedAlbums.isEmpty {
            albums = savedAlbums
            collectionView.reloadData()
            return
        }

        NetworkManager.shared.fetchAlbums(albumName: term) { [weak self] result in
            switch result {
            case .success(let fetchedAlbums):
                DispatchQueue.main.async {
                    self?.albums = fetchedAlbums.sorted { $0.collectionName < $1.collectionName }
                    self?.collectionView.reloadData()

                    for album in fetchedAlbums {
                        DiskStorageManager.shared.saveAlbum(album, for: term)
                    }

                    print("Successfully loaded \(fetchedAlbums.count) albums.")
                }
            case .failure(let error):
                print("Failed to load albums with error: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - UICollectionViewDataSource
extension SearchViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        albums.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: AlbumCollectionViewCell.id,
            for: indexPath)
                as? AlbumCollectionViewCell else {
            return UICollectionViewCell()
        }

        let album = albums[indexPath.item]
        let urlString = album.artworkUrl100

        NetworkManager.shared.loadImage(from: urlString) { loadedImage in
            DispatchQueue.main.async {
                guard let cell = collectionView.cellForItem(at: indexPath) as? AlbumCollectionViewCell  else {
                    return
                }
                cell.configure(with: album, image: loadedImage)
            }
        }
        return cell
    }
}

// MARK: - UICollectionViewDelegate
extension SearchViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {

        let albumViewController = AlbumViewController()
        let album = albums[indexPath.item]
        albumViewController.album = album
        navigationController?.pushViewController(albumViewController, animated: true)
    }
}

// MARK: - UISearchBarDelegate
extension SearchViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        guard let searchTerm = searchBar.text, !searchTerm.isEmpty else {
            return
        }
        DiskStorageManager.shared.saveSearchTerm(searchTerm)
        searchAlbums(with: searchTerm)
    }
}
