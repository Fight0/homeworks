import pickle 
 
def save_model(model, pkl_filename = "pickle_model"): 
    path = 'models/' + pkl_filename + '.pkl'
    with open(path, 'wb') as file: 
        pickle.dump(model, file)

def load_model(pkl_filename):
    path = 'models/' + pkl_filename + '.pkl'
    with open(path, 'rb') as file: 
        pickle_model = pickle.load(file)
