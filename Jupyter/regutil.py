import numpy as np
import pandas as pd

def add_continuous(df: pd.DataFrame, series: pd.Series, column_name: str) -> pd.DataFrame:
    '''
    Safely adds the log value of a continuous variable to a modeling dataset by accounting for observations that may have a value of zero.
    If any observations contain a zero then the entire series values will be increased by one before taking the log.
    
        Parameters:
            df (pandas.DataFrame): The data frame containing the modeling data
            series (pandas.Series): The series of continuous data to add to the modeling data
            column_name (str) : The column name for the new column
            
        Returns:
            (pandas.DataFrame) The data frame of modeling data with the new column added
    '''
    if (series.eq(0).any()):
        s = pd.Series(np.log(series + 1), name = column_name)
    else:
        s = pd.Series(np.log(series), name = column_name)
    return pd.concat([df, s], axis = 1)

def add_binaries(df, categorical, base, prefix, min_sales = 0):
    '''
    Creates binary variables from a series of categorical data values and adds them to a modeling dataset
    
        Parameters:
            df (pandas.DataFrame): The data frame containing the modeling data
            categorical (pandas.Series): The series of categorical data values
            base (str) : The categorical value to use as the base and therefore not crate a binary variable representation
            prefix (str) : The prefix to append to the variable column name
            min_sales (int) : The minimum number of sales required to create the binary column
        
            
        Returns:
            (pandas.DataFrame) The data frame of modeling data with the new binary columns added
    '''
    data = pd.get_dummies(categorical, prefix = prefix).astype(float)
    data.drop(base, axis = 1, inplace = True)
    for x in data:
        if len(data.loc[data[x] == 1, x]) < min_sales:
            print("Insufficent Sales: " + x)
            data.drop(x, axis = 1, inplace = True)
           
    return pd.concat([df, data], axis = 1)


def estimate_parcel_value(parcel_data: pd.DataFrame, model_coefficients: pd.Series) -> pd.Series:
    '''
    Dynamically builds a prediction statement based on model parameters and the predict parcel values from a given parcel data set
    
        Parameters:
            parcel_data (pandas.DataFrame): The data frame of parcel data that the prediction is based on
            model_coefficients (pandas.Series) : A series of model coefficients index by the variable names         
            
        Returns:
            (pandas.Series) The predicted values based on the model coefficients and parcel data.
    '''    
    s = "lambda x: " + str(model_coefficients['const'])
    
    for i,c in model_coefficients.drop('const').items():
        s += " + (" + str(c) + " * x['" + str(i) + "'])" 
    
    f = eval(s)
    return np.exp(parcel_data.apply(f, axis = 1))

# Calculates model coverage by parameters
# with optional grouping
def get_parameter_coverage(df: pd.DataFrame) -> pd.Series:
    '''
    Builds a series with sales coverage by model coefficient.
    
        Parameters:
            df (pandas.DataFrame): The data frame of parcel data that the prediction is based on            
            
        Returns:
            (pandas.Series) The coefficient sales coverage by coefficient name.
    '''    
    results = pd.Series(name = 'Coefficient Coverage')
    
    for col in df.columns:
        if len(df[col].value_counts()) == 2:
            #It's a Binary
            results[col] = len(df[df[col] == 1])                
        else:
            #It's Continuous
            results[col] = len(df[df[col] != 0])
                
    return results


if __name__ == '__main__':
    pass