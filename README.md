<img width=200 src="https://raw.githubusercontent.com/daaniiieel/homie/master/.github/logo.svg" alt="logo"/>

# Homie

Homie is a simple command line application, that can sync tasks from multiple sources (Google Classroom or KRÉTA) to a Todoist to-do list. It's designed to run with `cron` every x minutes.

## Setup
- From the [Google Developers Console](https://console.developers.google.com), set up a new API project with the Classroom api. Go to the Credentials tab, and download the `credentials.json` for the type `Web application`
- Download the latest executable from the releases page, or, clone this repo and cd to the `bin/` folder.
- Place the `credentials.json` you downloaded in the same folder as `homie.dart` or the executable.
- Open `credentials.json`. Add two sections:

  1. an entry named 'todoist', and a child to it named 'token', with your api token (get it from [here](https://todoist.com/prefs/integrations)):
   ```json
   "todoist": {
    "token": "your-api-token-here"
   }
   ```
    2. an entry named 'kreta', with your KRÉTA login deitails:
   ```json
   "kreta": {
    "username": "username",
    "password": "password",
    "schoolCode": "klikXXXXX"
   }
   ```
- Start the executable with `dart homie.dart` or `./homie.exe`. The first time you run the program, it will prompt you with a Google auth dialog in your browser. Follow the steps, then copy-paste the code into the terminal. After this, it'll automatically refresh the token every time, you don't need to do anything.

## Thanks to
- [@bczsalba](https://github.com/bczsalba): Name suggestion


> This is an unofficial client for KRÉTA.
