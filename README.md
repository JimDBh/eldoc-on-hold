# eldoc-on-hold

This package extends `eldoc` to display documentations with a delay.

## Installation

This package is not on Melpa, so the best ways would be to use
[straight.el](https://github.com/raxod502/straight.el) or
[quelpa.el](https://github.com/quelpa/quelpa).

Alternatively one could download the files to one's load path and
`require 'eldoc-on-hold`.

Example using `straight` and `use-package`:

```lisp
(use-package eldoc-on-hold
  :straight (:type git :host github :repo "JimDBh/eldoc-on-hold")
  :demand t
  :after eldoc
  :bind
  (("C-c h" . eldoc-on-hold-pick-up))
  :custom
  ((eldoc-on-hold-delay-interval 10))
  :config
  (global-eldoc-on-hold-mode 1))
```

## Usage

When `global-eldoc-on-hold-mode` is on, `eldoc` will wait for an extra
time of `eldoc-on-hold-delay-interval` seconds to display the message.

Note that this is in addition to `eldoc-idle-delay`, however `eldoc-idle-delay`
delays the __calculation__ of eldoc info, while `eldoc-on-hold-delay-interval`
delays the __display__ of the info.

An extra command, `eldoc-on-hold-pick-up` is also provided to immediately
display the eldoc message.

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for details.

## License

Apache 2.0; see [`LICENSE`](LICENSE) for details.

## Disclaimer

This project is not an official Google project. It is not supported by
Google and Google specifically disclaims all warranties as to its quality,
merchantability, or fitness for a particular purpose.
