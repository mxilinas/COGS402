1. Clone the repository
    ```bash
    $git clone https://github.com/mxilinas/COGS402.git
    ```
2. Create a new python virtual environment and activate it
    ```bash
    $python -m venv venv.gdrl && source venv.gdrl/bin/activate
    ```
3. Install sample factory and gdrl packages
    ```bash
    $pip install godot-rl sample-factory
    ```
4. Open godot, import the project, and export the main environment.
    - Make sure to install the preset for your operating system in the godot 
    export menu.
    - Export the build to the repository directory.
    
5. From the repository directory, run the test command.
    ```bash
    $./scripts/test.sh chase 1 1 chase
    ```

