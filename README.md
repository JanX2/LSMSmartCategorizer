LSMSmartCategorizer
===================

NOTE: Some of the functionality requires an internet connection.

## 1. What is this project?

LSMSmartCategorizer uses Latent Semantic Mapping (LSM) framework to 
categorize news feeds. It intends to provide an example of basic usage 
of LSM framework.

Sadly, the PubSub framework that is used herein has been deprecated as of 10.9. 
You are very much welcome to write a better sample app using another way to 
acquire RSS feeds or even using another type of data entirely. 

## 2. How should I study the source code?

To configure this project, you should first run

	git submodule update --init --recursive

There are nineteen source files in this project. You should focus on 
five of them, which are contained in an external submodule:
LSMClassifier.h/.m 
LSMClassifierResults.h/.m
LSMClassifierResultsPrivate.m. 

LSM framework is a Carbon framework. The five files listed above implement two
Objective-C classes, which encapsulate all LSM functionalities required 
by this application. These five files are thoroughly commented. 

Beside those five files, you might also want to look at these three methods:

    [TrainingWindowController doTrainAndSave]
    [EvalWindowController doLoadMap:]
    [EvalWindowController processFeedData:fromURL:]

Those three methods are users of LSMClassifier and LSMClassifierResults.

The rest of the source code files are there for the purpose of making
this a usable application.


## 3. How is this application used?

### 3.1 Introduction

Similar to most supervised machine learning technique, the usage of LSM
consists of two parts, training and evaluation. During training stage, 
you provide to the application some news feeds which have already been 
categorized. The LSM framework will create a map based on the data you 
provide. During the evaluation stage, you can provide news feeds that the 
application has not seen before. The LSM framework will use the trained map
to categorize those feeds for you. 

In this application, you train new maps in the Training window, and evaluate
in the Evaluation window. You can switch between the two windows using the
“Window” menu.

NOTE: The main purpose of this sample application is to demonstrate the
usage of the LMS framework. It is not our intent, in this application,
to optimize the classification accuracy.

### 3.2 Training

In the Training window, there are two ways you can provide training data,
using a directory hierarchy that contains the news feed files, or using
a property list file that contains URLs to the feeds.

A sample property list file, named "training_rss_categories.plist", is 
included in the project and the application bundle. You can follow its
format to create you own training property list.

If you want to use new feeds stored on your filesystem, you should make 
your training data hierarchy look like:

    /my/training/data/directory/
    +-- Category1/
        +-- feed1.xml
    	+-- feed2.xml
    	+-- …
    +-- Category2/
    	+-- feed1.xml
    	+-- feed2.xml
    	+-- …
    +-- …

You will provide the path "/my/training/data/directory/" to the application
as the top level directory. Within that directory, each sub-directory
represents a category which contains all the feeds that belong to that
category.

Once you have loaded training data, you can press the “Train and Save Map…” button
to train the map and save it to disk for later evaluation.

### 3.3 Evaluation

Once you create a map in the Training window, you may use it to categorize 
other feeds in Evaluation window. The first thing you need to do is to press
“Load Map…” button to load a map. Once the map is loaded, you will see all
existing categories in the outline view. Now you may press “Categorize
Feed File…” to read a feed from your filesystem, or press “Categorize Feed
URL…” to read a feed from a URL. The application will put the feed into
the category to which it thinks the feed belongs. You will see the result
in the outline view. 

If you click “Categorize Feed URL…”, you will get some pre-populated feed 
URLs to choose from.
