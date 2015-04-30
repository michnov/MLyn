from sklearn.svm import SVC
from sklearn.neighbors import KNeighborsClassifier
from sklearn.naive_bayes import MultinomialNB
from sklearn.tree import DecisionTreeClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.linear_model import Perceptron
from sklearn.feature_extraction import DictVectorizer
from sklearn import tree
import cPickle
import baseline
import sys

class Model:

    model = None
    vectorizer = None

    def __init__(self, model_type=None, model_params=""):
        if (model_type == None):
            self.model = None
            self.vectorizer = None
            return

        if (model_type == "baseline"):
            self.model = baseline.Baseline()
        elif (model_type == "svm"):
            self.model = eval("SVC(" + model_params + ")")
            #self.model = SVC(kernel="linear")
        elif (model_type == "knn"):
            self.model = eval("KNeighborsClassifier(" + model_params + ")")
            #self.model = KNeighborsClassifier(n_neighbors=3)
        elif (model_type == "naive_bayes"):
            self.model = MultinomialNB()
        elif (model_type == "decision_trees"):
            self.model = DecisionTreeClassifier(random_state=0)
        elif (model_type == "log_regression"):
            self.model = LogisticRegression()
        elif (model_type == "perceptron"):
            self.model = Perceptron()
        else:
            print >> sys.stderr, "Model of type " + model_type + " is not supported."

        self.vectorizer = DictVectorizer(sparse=True)
    
    def fit(self, X, y):
        X = self.vectorizer.fit_transform(X)
        self.model.fit(X, y)

    def predict(self, x):
        x = self.vectorizer.transform(x)
        return self.model.predict(x)
    
    def predict_proba(self, x):
        x = self.vectorizer.transform(x)
        return self.model.predict_proba(x)

    def predict_loss(self, X):
        probs = self.predict_proba(X)
        return probs[:,0]

    def score(self, X, y):
        X = self.vectorizer.transform(X)
        return self.model.score(X, y)

    def save(self, file_path):
        f = open(file_path, "w")
        cPickle.dump((self.model, self.vectorizer), f)
        f.close()

    def load(self, file_path):
        f = open(file_path, "r")
        (self.model, self.vectorizer) = cPickle.load(f)
        f.close()
        
    def print_params(self, file_path):
        f = open(file_path, "w")
        if (self.model.__class__.__name__ == "DecisionTreeClassifier"):
            f = tree.export_graphviz(self.model, out_file=f)
        f.close()
