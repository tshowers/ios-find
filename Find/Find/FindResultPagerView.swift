import SwiftUI
import UIKit

/// Standard iOS horizontal paging between results -
/// `UIPageViewController(transitionStyle: .scroll)`, the same swipe as Photos
/// or the App Store. (It used to be an iBooks-style page curl, which suited
/// the original paper look but not the flat redesign.) The data source
/// (before/after controllers) gives swipe-forward AND swipe-back, and the
/// pager's Back/Next buttons keep working too: a button-driven index change
/// is detected in `updateUIViewController` and animated with the same slide
/// via `setViewControllers(direction:animated:)`.
struct FindResultPagerView: UIViewControllerRepresentable {
    let response: FindSearchResponse
    @Binding var currentIndex: Int
    let screenWidth: CGFloat
    let feedbackStore: FindFeedbackStore
    /// When true, page index -1 is a valid page (the backend's own generated
    /// answer, ahead of every ranked result) - see ResultPageView's
    /// `isGroundedAnswerSlide`.
    var hasLeadingAnswer: Bool = false

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pageVC = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal,
            // A small gap so neighbouring result cards don't touch mid-swipe.
            options: [.interPageSpacing: 16]
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
        var parent: FindResultPagerView

        init(_ parent: FindResultPagerView) {
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
                rootView: ResultPageView(
                    response: parent.response,
                    pageIndex: index,
                    screenWidth: parent.screenWidth,
                    feedbackStore: parent.feedbackStore,
                    // The headline "Next" preview: moving the binding makes
                    // updateUIViewController slide to that page.
                    onNext: { [weak self] in
                        guard let self, self.parent.response.results.indices.contains(index + 1) else { return }
                        self.parent.currentIndex = index + 1
                    }
                )
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
