# Contributing to zBench
We want to make contributing to this project simple and convenient.

This document provides a high level overview of the contribution process,
please also review our [Coding Standards](https://ziglang.org/documentation/master/#toc-Style-Guide).

## Our Development Process
Contributions can be made through regular GitHub pull requests.

## Pull Requests
We actively welcome your pull requests. If you are planning on doing a larger
chunk of work or want to change the API, make sure to file an
issue first to get feedback on your idea.

1. Fork the repo and create your branch from `main`.
2. If you've added code that should be tested, add tests.
3. Ensure the test suite passes and your code lints.
4. Consider squashing your commits (`git rebase -i`). One intent alongside one
   commit makes it clearer for people to review and easier to understand your
   intention.

## Issues
We use GitHub issues to track public bugs. Please ensure your description is
clear and has sufficient instructions to be able to reproduce the issue.

## Coding Style
* The zBench coding style is generally based on the
  [Zig Coding Standards](https://ziglang.org/documentation/master/#toc-Style-Guide).
* Match the style you see used in the rest of the project. This includes
  formatting, naming things in code, naming things in documentation.
* Run `zig fmt`, using the standard configuration.

## License
By contributing to zBench, you agree that your contributions will be licensed
under the LICENSE file in the root directory of this source tree.
