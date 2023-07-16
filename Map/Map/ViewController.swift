import UIKit
import MapKit
import CoreLocation

class ViewController: UIViewController {
    let mapView = MKMapView()
    let locationManager = CLLocationManager()
    var universities: [University] = []
    let activityIndicator = UIActivityIndicatorView(style: .large)
    var universityDistanceLabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        configureProperties()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    func setupUI() {
        view.backgroundColor = .white
        layoutMapView()
        layoutTrackingButton()
        layoutActivityIndicator()
        layoutUniversityLabel()
    }
    
    func configureProperties() {
        mapView.register(MKAnnotationView.self, forAnnotationViewWithReuseIdentifier: NSStringFromClass(UniversityAnnotation.self))
        mapView.delegate = self
        locationManager.delegate = self
        Task {
            universities = await fetchUniversityData()
            addAnnotaionsInMap()
        }
    }
    
    func layoutMapView() {
        self.view.addSubview(mapView)
        mapView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            mapView.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor),
            mapView.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor),
            mapView.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor),
            mapView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor)
        ])
    }
    
    func layoutTrackingButton() {
        let button = MKUserTrackingButton(mapView: mapView)
        button.layer.backgroundColor = UIColor(white: 1, alpha: 0.8).cgColor
        button.layer.borderColor = UIColor.white.cgColor
        button.layer.borderWidth = 1
        button.layer.cornerRadius = 5
        button.clipsToBounds = true
        mapView.addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.bottomAnchor.constraint(equalTo: mapView.safeAreaLayoutGuide.bottomAnchor, constant: -50),
            button.trailingAnchor.constraint(equalTo: mapView.safeAreaLayoutGuide.trailingAnchor, constant: -30),
            button.heightAnchor.constraint(equalToConstant: 45),
            button.widthAnchor.constraint(equalToConstant: 45),
        ])
    }
    
    func layoutActivityIndicator() {
        activityIndicator.hidesWhenStopped = true
        activityIndicator.color = .red
        mapView.addSubview(activityIndicator)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: mapView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: mapView.centerYAnchor)
        ])
    }
    
    func layoutUniversityLabel() {
        universityDistanceLabel.numberOfLines = 0
        universityDistanceLabel.textAlignment = .center
        universityDistanceLabel.font = UIFont(name: "HelveticaNeue-Bold", size: 25.0)
        universityDistanceLabel.textColor = .darkText
        universityDistanceLabel.shadowColor = .blue
        mapView.addSubview(universityDistanceLabel)
        universityDistanceLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            universityDistanceLabel.bottomAnchor.constraint(equalTo: mapView.bottomAnchor, constant: -5),
            universityDistanceLabel.centerXAnchor.constraint(equalTo: mapView.centerXAnchor)
        ])
        universityDistanceLabel.isHidden = true
    }
}

// MARK: CLLocationManagerDelegate

extension ViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            enableLocationViaSettings()
        case .authorizedAlways, .authorizedWhenInUse:
            mapView.showsUserLocation = true
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.startUpdatingLocation()
            print("Enabled loaction permission for Map")
        @unknown default:
            print("Unknown location authorisation status")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            return
        }
        let region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 10000, longitudinalMeters: 10000)
        mapView.setRegion(region, animated: true)
    }
}

// MARK: MKMapViewDelegate

extension ViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard !annotation.isKind(of: MKUserLocation.self) else {
            return nil
        }
        let reuseIdentifier = NSStringFromClass(UniversityAnnotation.self)
        var annotationView: MKAnnotationView = MKAnnotationView()
        if let annotation = annotation as? UniversityAnnotation {
            annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier, for: annotation)
            annotationView.canShowCallout = true
            // Provide the annotation view's image.
            annotationView.image = #imageLiteral(resourceName: "flag")
            let offset = CGPoint(x: 0, y: 0)
            annotationView.centerOffset = offset
        }
        return annotationView
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let annotation = view.annotation as? UniversityAnnotation else { return }
        universityDistanceLabel.isHidden = true
        mapView.removeOverlays(mapView.overlays)
        activityIndicator.startAnimating()
        showRouteBetweenCurrentLocationToSelectedUniversity(annotation: annotation)
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let polyline = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = .blue
            renderer.lineWidth = 5
            return renderer
        }
        return MKOverlayRenderer()
    }
}

// MARK: Helper Methods

extension ViewController {
    
    func addAnnotaionsInMap() {
        for university in universities {
            let coordinate = CLLocationCoordinate2DMake(university.geometry.y, university.geometry.x)
            let title = university.attributes.University_Chapter
            let subtitle = "\(university.attributes.City) \(university.attributes.State)"
            mapView.addAnnotation(UniversityAnnotation(coordinate: coordinate, title: title, subtitle: subtitle))
        }
    }
    
    func enableLocationViaSettings() {
        showAlertToEnableLoaction()
    }
    
    func showAlertToEnableLoaction() {
        let alertViewController = UIAlertController(title: "Location permissions required to use Map", message: "Turn on location in settings screen", preferredStyle: .alert)
        let settingsAction = UIAlertAction(title: "Settings", style: .default) {_ in
            if let url = URL(string:UIApplication.openNotificationSettingsURLString) {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            }
        }
        alertViewController.addAction(settingsAction)
        present(alertViewController, animated: true)
    }
    
    func showUnavailableRouteAlert() {
        let alertViewController = UIAlertController(title: "The automobile route is unavailble between university and current location", message: "", preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Ok", style: .default)
        alertViewController.addAction(okAction)
        present(alertViewController, animated: true)
    }
    
    func showRouteBetweenCurrentLocationToSelectedUniversity(annotation: UniversityAnnotation) {
        let currentLocation = mapView.userLocation.coordinate
        let universityLocation = annotation.coordinate
        let currentPlacemark = MKPlacemark(coordinate: currentLocation)
        let universityPlacemark = MKPlacemark(coordinate: universityLocation)
        let currentMapItem = MKMapItem(placemark: currentPlacemark)
        let universityMapItem = MKMapItem(placemark: universityPlacemark)
        let directionRequest = MKDirections.Request()
        directionRequest.source = currentMapItem
        directionRequest.destination = universityMapItem
        directionRequest.transportType = .any
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            Task {
                do {
                    let directions = MKDirections(request: directionRequest)
                    let response = try await directions.calculate()
                    let route = response.routes[0]
                    DispatchQueue.main.async {
                        self.addRoute(route: route)
                    }
                } catch {
                    print("Error getting directions: \(error.localizedDescription)")
                    self.showUnavailableRouteAlert()
                }
            }
        }
    }
    
    func addRoute(route: MKRoute) {
        self.mapView.addOverlay(route.polyline, level: .aboveRoads)
        let rect = route.polyline.boundingMapRect
        self.mapView.setRegion(MKCoordinateRegion(rect), animated: true)
        self.universityDistanceLabel.text = "University to User location\nDistance: \(route.distance) meters"
        self.activityIndicator.stopAnimating()
        self.universityDistanceLabel.isHidden = false
    }
}
