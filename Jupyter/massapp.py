import numpy as np
import pandas as pd
import statsmodels.api as sm
import seaborn as sns



#----------------------------------
# Mass appraisal functions
#----------------------------------

def weighted_mean(predicted_values: pd.Series, sales_prices: pd.Series) -> np.float64:
    '''
    Returns the weighted mean assessment ratio.
    
        Parameters:
            predicted_values (pandas.Series): Series of the parcel predicted values
            sales_prices   (pandas.Series): Series of the parcel sales prices
            
        Returns:
            weighted_mean (numpy.float64) mean ratio of the parcel predicted values
            
    '''
    weighted_mean: np.float64 = predicted_values.sum() / sales_prices.sum()
    return weighted_mean

def average_deviation(predicted_values: pd.Series, sales_prices: pd.Series) -> np.float64:
    '''
    Returns the average deviation.
    
        Parameters:
            predicted_values (pandas.Series): Series of predicted parcel values
            sales_prices (pandas.Series): Series of the parcel sales prices
            
        Returns:
            average_deviation (numpy.float64): Average difference between each parcel prediction
            
    '''
    median_ratio = (predicted_values / sales_prices).median()
    average_deviation = ((predicted_values / sales_prices) - median_ratio).abs().sum() / len(sales_prices) 
    return average_deviation

def COD(predicted_values: pd.Series, sales_prices: pd.Series) -> np.float64:
    '''
    Returns the coefficient of dispersion.
    
        Parameters:
            predicted_values (pandas.Series): Series of predicted parcel values
            sales_prices (pandas.Series): Series of parcel sale prices
            
        Returns:
            coefficient_of_dispersion (numpy.float64) : The average deviation as a percentage
            
    '''
    median_ratio = (predicted_values / sales_prices).median()
    coefficient_of_dispersion = (100.00 * average_deviation(predicted_values, sales_prices)) / median_ratio
    return coefficient_of_dispersion

def PRD(predicted_values: pd.Series, sales_prices: pd.Series) -> np.float64:
    '''
    Returns the price related differential
    
        Parameters:
            predicted_values (pandas.Series): Series of predicted parcel values
            sales_prices (pandas.Series): Series of parcel sales prices
            
        Returns:
            price_related_differential (numpy.float64) : a statistic for measuring assessment regressivity or progressivity
            
    '''
    mean_ratio = (predicted_values / sales_prices).mean()
    price_related_differential = mean_ratio / weighted_mean(predicted_values, sales_prices)
    return price_related_differential

def PRB(predicted_values: pd.Series, sales_prices: pd.Series, show_graph: bool=False) -> dict:
    '''
    Returns the price related bias
    
        Parameters:
            predicted_values (pandas.Series): Series of predicted parcel values
            sales_prices (pandas.Series): Series of parcel sales prices
            show_graph (bool): If true creates the plot of assessment ratios against value proxy as percentages when using Jupyter Notebook
            
        Returns:
            dict
                Key: PRB, Value: (numpy.float64) The PRB statistic
                Key: sig, Value: (numpy.float64) The statistical significance of the PRB statistic            
    '''
    ratio = predicted_values / sales_prices
    median_ratio = ratio.median()
    value = (0.50 * sales_prices) + (0.50 * predicted_values / predicted_values.median())
    ln_value = np.log(value) / np.log(2)
    pct_diff = (ratio - median_ratio) / median_ratio
    model_data = sm.add_constant(ln_value)
    model = sm.OLS(pct_diff, model_data).fit()
    
    if show_graph:
        p = sns.lmplot(x='ln_value', y='pct_diff', data = pd.DataFrame.from_dict({"ln_value" : ln_value, "pct_diff" : pct_diff}), lowess = True, line_kws={'color': 'red'})
        p.figure.set_figwidth(10)
        p.figure.set_figheight(6)
        p.set_axis_labels('LN("Value")/.693', '(ASR-Median) / Median')
        p.ax.ticklabel_format(useOffset=False)
    return {"PRB" : model.params[0], "sig" : model.pvalues[0]}

def ratio_statistics(df: pd.DataFrame, group=lambda x: True, predicted_value_column: str = 'ESP', sales_price_column: str = 'SalesPrice') -> pd.DataFrame:
    '''
    Returns a data frame of common statistical functions
    
        Parameters:
            df (pandas.DataFrame): DataFrame containing the appraisal details
            group (str): Dataframe column to group the data by
            predicted_value_column (str): Name of the predicted value column
            sales_price_column (str): Name of the sales price column
            
        Returns:
            pandas.DataFrame
                column: Count, Value: (numpy.float64) The parel count
                column: Mean, Value: (numpy.float64) The mean ratio
                column: Median, Value: (numpy.float64) The median ratio
                column: WgtMean, Value: (numpy.float64) The weighted mean ratio
                column: Min, Value: (numpy.float64) The minimum ratio
                column: Max, Value: (numpy.float64) The maximum ratio
                column: PRD, Value: (numpy.float64) The price related differential
                column: COD, Value: (numpy.float64) The coefficient of dispersion
                column: PRB, Value: (numpy.float64) The price related bias
                column: sig, Value: (numpy.float64) The significance of the price related bias statistic      
    '''
    stats = pd.DataFrame(columns = ['Count', 'Mean', 'Median', 'WgtMean', 'Min', 'Max', 'PRD', 'COD', "PRB", "sig"])
    if isinstance(group, str):
        stats.index.name = group
    for name, gData in df.groupby(by=group, observed = True):
        ratio = gData[predicted_value_column] / gData[sales_price_column]
        prb_results = PRB(gData[predicted_value_column], gData[sales_price_column])
        stats.loc[name] = [
            len(gData.index),
            '%0.3f' % ratio.mean(),
            '%0.3f' % ratio.median(),
            '%0.3f' % weighted_mean(gData['ESP'], gData['SalesPrice']),
            ratio.min(),
            ratio.max(),
            '%0.3f' % PRD(gData['ESP'], gData['SalesPrice']),
            '%0.3f' % COD(gData['ESP'], gData['SalesPrice']),
            '%0.3f' % prb_results['PRB'],
            '%0.3f' % prb_results['sig']
        ]
    return stats


if __name__ == '__main__':
    
    # Table 8 - Calculating the weighted mean - IAAO Mass Appraisal of Real Property page 323
    appraised_values = pd.Series([100_000, 100_000, 100_000, 100_000, 200_000])
    sales_prices = pd.Series([125_000, 125_000, 125_000, 125_000, 500_000])
    assert weighted_mean(appraised_values, sales_prices) == .60, "weighted_mean failed to calculate the correct value."
    
    # Table 11 - Calculating the Coefficient of Dispersion (COD) - IAAO Mass Appraisal of Real Property page 236
    appraised_values = pd.Series([25500, 57000, 39000, 90000, 51000, 93000, 49500])
    sales_prices = pd.Series([75000, 150000, 90000, 180000, 90000, 150000, 75000])
    assert round(average_deviation(appraised_values, sales_prices), 3) == .099, "average deviation failed to calculate the correct value."
    assert round(COD(appraised_values, sales_prices), 1) == 19.8, "COD failed to calculate the correct value."
    
    # Table 14 - Calculating the Price Related Differential (PRD)- IAAO Mass Appraisal of Real Property page 341
    appraised_values = pd.Series([50000, 48000, 62000, 80000, 120000, 158000])
    sales_prices = pd.Series([40000, 60000, 80000, 100000, 120000, 140000])
    assert round(PRD(appraised_values, sales_prices), 3) == 1.00, "PRD failed to calculate the correct value."
    
    # Table 2 - A Measure fo Vertical Equity - https://www.agjd.com/documents/The%20Coefficient%20of%20Price-Related%20Bias.pdf
    assessed_values = pd.Series([131670, 170190, 152820, 152370, 164340, 156870, 167670, 179010, 183600, 175590, 187200, 197820,
        207180, 198990, 223830, 216630, 241560, 238950, 247410, 240300, 283680, 285120, 310950, 302220, 318600, 341010, 357570, 
        354240, 411930, 415440])

    sales_prices = pd.Series([139500, 175950, 155000, 169700, 159250, 182900, 205000, 230350, 215650, 199950, 240000, 224900, 275000,
        289000, 260850, 290000, 294000, 249500, 329000, 279000, 335000, 314000, 397500, 389000, 369000, 459000, 427900,
        526000, 545500, 590000])

    prb = PRB(assessed_values, sales_prices)
    assert round(prb['PRB'], 3) == -.138, "PRB failed to calculate the correct value."
    assert round(prb['sig'], 3) == 0.000, "PRB failed to calculate the correct significance."

    ratio_statistics(pd.Series(), pd.Series(), group='Nbhd')
    
    
    
    
    