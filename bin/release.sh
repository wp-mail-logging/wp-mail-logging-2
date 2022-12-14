#! /bin/bash
# See https://github.com/GaryJones/wordpress-plugin-git-flow-svn-deploy for instructions and credits.

echo
echo "WordPress Plugin Git-Flow SVN Deploy v1.0.0-dev2"
echo
echo "Step 1. Let's collect some information first."
echo
echo "Default values are in brackets - just hit enter to accept them."
echo

# Get some user input
# Can't use the -i flag for read, since that doesn't work for bash 3
#printf "1a) WordPress Repo Plugin Slug e.g. my-awesome-plugin: "
#read -e PLUGINSLUG
#echo

# Set up some default values. Feel free to change these in your own script
CURRENTDIR=`pwd`
PLUGINSLUG="wp-mail-logging"
default_svnpath="/tmp/$PLUGINSLUG-release"
default_svnurl="http://plugins.svn.wordpress.org/$PLUGINSLUG"
default_svnuser="wysija"
default_plugindir="$CURRENTDIR/../../$PLUGINSLUG"
default_mainfile="$PLUGINSLUG.php"
default_releases_path="$default_plugindir/releases"

SVNPATH=$default_svnpath # Populate with default if empty
SVNURL=$default_svnurl # Populate with default if empty
SVNUSER=$default_svnuser # Populate with default if empty
PLUGINDIR=$default_plugindir # Populate with default if empty
MAINFILE=$default_mainfile # Populate with default if empty
RELEASESPATH=$default_releases_path

echo "Release data:"
echo
echo "Slug: $PLUGINSLUG"
echo "Temp checkout path: $SVNPATH"
echo "Remote SVN repo: $SVNURL"
echo "SVN username: $SVNUSER"
echo "Plugin directory: $PLUGINDIR"
echo "Main file: $MAINFILE"
echo "Releases path: $RELEASESPATH"
echo

printf "OK to proceed (y|n)? "
read -e input
PROCEED="${input:-y}"
echo

# Allow user cancellation
if [ "$PROCEED" != "y" ]; then echo "Aborting..."; exit 1; fi

# git config
GITPATH="$PLUGINDIR/" # this file should be in the base of your git repository

# Let's begin...
echo ".........................................."
echo
echo "Preparing to deploy WordPress plugin"
echo
echo ".........................................."
echo

# Check version in readme.txt is the same as plugin file after translating both to unix line breaks to work around grep's failure to identify mac line breaks
NEWVERSION1=`grep "^Stable tag:" $GITPATH/readme.txt | awk -F' ' '{print $NF}' | tr -d '\r'`
echo "readme.txt version: $NEWVERSION1"
NEWVERSION2=`grep "Version:" $GITPATH/$MAINFILE | awk -F' ' '{print $NF}' | tr -d '\r'`
echo "$MAINFILE version: $NEWVERSION2"

if [ "$NEWVERSION1" != "$NEWVERSION2" ]; then echo "Version in readme.txt & $MAINFILE don't match. Exiting...."; exit 1; fi

echo "Versions match in readme.txt and $MAINFILE. Let's proceed..."

# GaryJ: Ignore check for git tag, as git flow release finish creates this.
#if git show-ref --tags --quiet --verify -- "refs/tags/$NEWVERSION1"
#	then
#		echo "Version $NEWVERSION1 already exists as git tag. Exiting....";
#		exit 1;
#	else
#		echo "Git version does not exist. Let's proceed..."
#fi

echo "Changing to $GITPATH"
cd $GITPATH
# GaryJ: Commit message variable not needed . Hard coded for SVN trunk commit for consistency.
echo -e "Enter a commit message for this new version: \c"
read COMMITMSG
# GaryJ: git flow release finish already covers this commit.
git commit -am "$COMMITMSG"

# GaryJ: git flow release finish already covers this tag creation.
echo "Tagging new version in git"
git tag -a "release/$NEWVERSION1" -m "Tagging version $NEWVERSION1"

echo "Pushing git master to origin, with tags"
git push origin master
git push origin master --tags

echo
echo "Creating local copy of SVN repo trunk ..."
svn checkout $SVNURL $SVNPATH --depth immediates
svn update --quiet $SVNPATH/trunk --set-depth infinity

echo "Ignoring GitHub specific files"
svn propset svn:ignore "README.md
CONTRIBUTING.md
README.md
phpunit.xml
Thumbs.db
.travis.yml
.git
.gitignore
tests
bin
composer.json
composer.lock" "$SVNPATH/trunk/"

# Release the built zip
echo "Extracting the build zip"
unzip "$RELEASESPATH/$PLUGINSLUG-$NEWVERSION1.zip" -d "$SVNPATH/trunk/"

# Support for the /assets folder on the .org repo.
echo "Moving assets"
# Make the directory if it doesn't already exist
mkdir -p $SVNPATH/assets/
mv $SVNPATH/trunk/assets/* $SVNPATH/assets/
svn add --force $SVNPATH/assets/
svn delete --force $SVNPATH/trunk/assets

printf "OK to proceed? This will actually release $PLUGINSLUG $NEWVERSION1 (y|n)? "
read -e input
PROCEED="${input:-y}"
echo

# Allow user cancellation
if [ "$PROCEED" != "y" ]; then echo "Aborting..."; exit 1; fi

echo "Changing directory to SVN and committing to trunk"
cd $SVNPATH/trunk/
# Delete all files that should not now be added.
svn status | grep -v "^.[ \t]*\..*" | grep "^\!" | awk '{print $2}' | xargs svn del
# Add all new files that are not set to be ignored
svn status | grep -v "^.[ \t]*\..*" | grep "^?" | awk '{print $2}' | xargs svn add
svn commit --username=$SVNUSER -m "Preparing for $NEWVERSION1 release"

echo "Updating WordPress plugin repo assets and committing"
cd $SVNPATH/assets/
# Delete all new files that are not set to be ignored
svn status | grep -v "^.[ \t]*\..*" | grep "^\!" | awk '{print $2}' | xargs svn del
# Add all new files that are not set to be ignored
svn status | grep -v "^.[ \t]*\..*" | grep "^?" | awk '{print $2}' | xargs svn add
svn update --accept mine-full $SVNPATH/assets/*
svn commit --username=$SVNUSER -m "Updating assets"

echo "Creating new SVN tag and committing it"
cd $SVNPATH
svn update --quiet $SVNPATH/tags/$NEWVERSION1
svn copy --quiet trunk/ tags/$NEWVERSION1/
# Remove assets and trunk directories from tag directory
svn delete --force --quiet $SVNPATH/tags/$NEWVERSION1/assets
svn delete --force --quiet $SVNPATH/tags/$NEWVERSION1/trunk
cd $SVNPATH/tags/$NEWVERSION1
svn commit --username=$SVNUSER -m "Tagging version $NEWVERSION1"

echo "Removing temporary directory $SVNPATH"
cd $SVNPATH
cd ..
rm -fr $SVNPATH/

echo "*** FIN ***"
