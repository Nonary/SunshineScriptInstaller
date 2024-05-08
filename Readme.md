# Project Name

This repository is designed to be used as a template for creating similar projects. It allows you to maintain an up-to-date version of the template while also customizing and adding your own content.

## Using This Repository as a Template

To use this repository as a template for your own project, follow these steps:

1. **Create a New Repository from the Template**
   - Navigate to the main page of this repository.
   - Above the file list, click the **Use this template** button.
   - Follow the prompts to create a new repository from this template.

## Setting Up the Upstream Repository

Once you have created your project from this template, you should set up this repository as an upstream to easily pull the latest changes:

1. **Add the Upstream Repository**
   - Open your terminal.
   - Change the current working directory to your local project.
   - Run the following command to add this repository as an upstream:
     ```
     git remote add upstream https://github.com/Nonary/SunshineScriptInstaller.git
     ```

2. **Verify the Upstream Repository**
   - To ensure the upstream repository was added correctly, you can run:
     ```
     git remote -v
     ```
   - You should see the URL for your fork as `origin`, and the URL for the original repository as `upstream`.

## Syncing with the Upstream Repository

To keep your repository up-to-date with the changes made in the template, you can merge changes from the upstream repository into your project:

1. **Fetch the Latest Changes from Upstream**
   - Run the following command to fetch the branches and their respective commits from the upstream repository:
     ```
     git fetch upstream
     ```

2. **Merge the Changes from Upstream/Main into Your Branch**
   - Ensure you are on your main branch by running:
     ```
     git checkout main
     ```
   - Merge the changes from the upstream main branch:
     ```
     git merge upstream/main --allow-unrelated-histories
     ```
   - If there are no conflicts, this will update your branch with the latest changes.

3. **Push the Merged Changes**
   - After merging, push the changes to your GitHub repository:
     ```
     git push origin main
     ```

## Making Your Own Changes

You can now proceed to make your own changes to the project. It's recommended to regularly sync with the upstream repository to ensure you have the latest updates and avoid merge conflicts.

## Contributing

Contributions to this template are welcome! Please read our contributing guidelines in `CONTRIBUTING.md` to learn how you can contribute.

## License

This project is licensed under the [MIT License](LICENSE).

---
Feel free to star this repository if you find it useful! Follow the maintenance updates and contribute to the original template to help improve it for everyone.
