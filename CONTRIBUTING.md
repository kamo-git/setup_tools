# Contributing Guide

## Development Workflow

To ensure code quality and security, all contributors must follow this workflow:

1.  **Create a Branch**: Never commit directly to `main`. Create a descriptive branch for your feature or fix.
    ```bash
    git checkout -b feature/your-feature-name
    ```
2.  **Pull Request**: Push your branch and create a Pull Request (PR).
3.  **Code Review**: Wait for the automated CodeRabbit review (and human reviews if applicable).
    *   **Language**: Japanese
    *   **Focus**: Security and Code Quality
4.  **Address Feedback**: Apply necessary fixes based on the review comments.
5.  **Merge**: Once approved, merge the PR into `main`.

## CodeRabbit Configuration

This project uses CodeRabbit for automated reviews. Configuration can be found in `.coderabbit.yaml`.
