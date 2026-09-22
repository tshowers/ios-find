import SwiftUI
import UIKit

/// The real iBooks-style page curl - `UIPageViewController(transitionStyle:
/// .pageCurl)` - ported from Network iOS's `PageCurlView`. Wrapping just
/// enough UIKit gets swipe-forward AND swipe-back for free via
/// `UIPageViewController`'s data source (before/after controllers), and the
/// existing shelf chevrons keep working too: a button-driven index change is
/// detected in `updateUIViewController` and animated with the same curl via
/// `setViewControllers(direction:animated:)`.
struct FindResultPageCurlView: UIViewControllerRepresentable {
    let response: FindSearchResponse
    @Binding var currentIndex: Int
    let screenWidth: CGFloat
    /// When true, page index -1 is a valid page (the backend's own generated
    /// answer, ahead of every ranked result) - see ResultPageView's
    /// `isGroundedAnswerSlide`.
    var hasLeadingAnswer: Bool = false

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pageVC = UIPageViewController(
            transitionStyle: .pageCurl,
            navigationOrientation: .horizontal
        )
        pageVC.dataSource = context.coordinator
        pageVC.delegate = context.coordinator
        pageVC.view.backgroundColor = .clear
        if let initial = context.coordinator.controller(for: currentIndex) {
            pageVC.setViewControllers([initial], direction: .forward, animated: false)
        }
        return pageVC
    }

    func updateUIViewController(_ pageVC: UIPageViewController, context: Context) {
        context.coordinator.parent = self

        let visibleIndex = pageVC.viewControllers?.first.flatMap(context.coordinator.index(of:))
        guard visibleIndex != currentIndex else { return }
        guard let target = context.coordinator.controller(for: currentIndex) else { return }

        let direction: UIPageViewController.NavigationDirection =
            currentIndex > (visibleIndex ?? currentIndex) ? .forward : .reverse
        pageVC.setViewControllers([target], direction: direction, animated: true)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: FindResultPageCurlView

        init(_ parent: FindResultPageCurlView) {
            self.parent = parent
        }

        // UIPageViewController expects a freshly-built controller for a
        // given position on every data-source call - it does its own
        // caching/lifecycle management, so this intentionally doesn't
        // memoize. `view.tag` carries the page index so the delegate
        // callback below can report which page landed.
        func controller(for index: Int) -> UIViewController? {
            let isValidLeadingAnswer = index == -1 && parent.hasLeadingAnswer
            guard isValidLeadingAnswer || parent.response.results.indices.contains(index) else { return nil }
            let host = UIHostingController(
                rootView: ResultPageView(response: parent.response, pageIndex: index, screenWidth: parent.screenWidth)
            )
            host.view.backgroundColor = .clear
            host.view.tag = index
            return host
        }

        func index(of controller: UIViewController) -> Int? {
            controller.view.tag
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerBefore viewController: UIViewController
        ) -> UIViewController? {
            guard let idx = index(of: viewController) else { return nil }
            return controller(for: idx - 1)
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            viewControllerAfter viewController: UIViewController
        ) -> UIViewController? {
            guard let idx = index(of: viewController) else { return nil }
            return controller(for: idx + 1)
        }

        func pageViewController(
            _ pageViewController: UIPageViewController,
            didFinishAnimating finished: Bool,
            previousViewControllers: [UIViewController],
            transitionCompleted completed: Bool
        ) {
            guard completed,
                  let visible = pageViewController.viewControllers?.first,
                  let idx = index(of: visible) else { return }
            parent.currentIndex = idx
        }
    }
}
