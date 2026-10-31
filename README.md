# Healthcare Risk Project: Conversation Notes

A condensed record of what we built and the fixes along the way. Replace `YOUR_FOLDER_NAME` with your Drive folder.

## 1. Excel work

**Lookup diagnosis name** (lock the range with `$`, otherwise it shifts when filled down and gives `#N/A`):

```
=VLOOKUP(E2,diagnoses!$A$2:$B$11,2,FALSE)
```

**Lookup outcome name** (OutcomeID is in column H):

```
=VLOOKUP(H2,outcomes!$A$2:$B$4,2,FALSE)
```

**Blood sugar flag** (labs has several rows per patient, so filter by TestName; 70 to 140 mg/dL used as the range):

```
=IF(COUNTIFS(labs!$B:$B,A2,labs!$C:$C,"Blood Sugar")=0,"No test",
 IF(MAXIFS(labs!$D:$D,labs!$B:$B,A2,labs!$C:$C,"Blood Sugar")>140,"High",
 IF(MINIFS(labs!$D:$D,labs!$B:$B,A2,labs!$C:$C,"Blood Sugar")<70,"Low","Normal")))
```

## 2. Load and merge in Colab

Run this in one cell so a re-run always starts clean:

```python
from google.colab import drive
drive.mount('/content/drive')

import pandas as pd

path = '/content/drive/MyDrive/YOUR_FOLDER_NAME/'

patients  = pd.read_csv(path + 'patients.csv')
diagnoses = pd.read_csv(path + 'diagnoses.csv')
labs      = pd.read_csv(path + 'labs.csv')
outcomes  = pd.read_csv(path + 'outcomes.csv')

df = (patients
      .merge(diagnoses, on='DiagnosisID', how='left')
      .merge(outcomes, on='OutcomeID', how='left'))

df['AdmissionDate'] = pd.to_datetime(df['AdmissionDate'])
df['DischargeDate'] = pd.to_datetime(df['DischargeDate'])
df['LengthOfStay'] = (df['DischargeDate'] - df['AdmissionDate']).dt.days
```

## 3. Abnormal lab count (tested, later removed from the model)

```python
abnormal_conditions = {
    'Blood Sugar': lambda x: x > 120,
    'Cholesterol': lambda x: x > 200,
    'Hemoglobin':  lambda x: x < 13
}

def count_abnormal_labs(patient_id):
    patient_labs = labs[labs['PatientID'] == patient_id]
    count = 0
    for test_name, condition in abnormal_conditions.items():
        test_results = patient_labs[patient_labs['TestName'] == test_name]
        count += test_results['Result'].apply(condition).sum()
    return count

df['AbnormalLabcount'] = df['PatientID'].apply(count_abnormal_labs)
```

## 4. ROC curve plot

```python
roc_auc = auc(fpr, tpr)

plt.figure()
plt.plot(fpr, tpr, color='blue', label=f'ROC curve (area = {roc_auc:.2f})')
plt.plot([0, 1], [0, 1], color='gray', linestyle='--')
plt.xlabel('False Positive Rate')
plt.ylabel('True Positive Rate')
plt.title('Receiver Operating Characteristic')
plt.legend(loc='lower right')
plt.show()
```

`roc_curve` needs a binary target. For three outcome classes, make it binary (for example Deceased vs. not) or draw one curve per class.

## 5. Save the model

```python
import joblib
joblib.dump(model, '/content/Risk_model1.pkl')
joblib.dump(model, '/content/drive/MyDrive/YOUR_FOLDER_NAME/Risk_model1.pkl')
```

A `.ipynb` file is a notebook, not a model, so it can't be loaded with `joblib`.

## 6. Streamlit app

Final working `app.py`. The column names must match training exactly: `Age`, `Lengthofstay`, `TreatmentCost`.

```python
%%writefile app.py
import streamlit as st
import pandas as pd
import joblib

model = joblib.load('Risk_model1.pkl')

st.title("Healthcare Risk Stratification App")

age = st.number_input("Age", min_value=0)
length_of_stay = st.number_input("Length of stay (days)", min_value=0)
treatment_cost = st.number_input("Treatment cost", min_value=0.0)

if st.button("Predict"):
    input_data = pd.DataFrame(
        [[age, length_of_stay, treatment_cost]],
        columns=['Age', 'Lengthofstay', 'TreatmentCost']
    )
    prediction = model.predict(input_data)[0]
    probability = model.predict_proba(input_data)[0][1]

    st.write(f"Risk Prediction: {'High Risk' if prediction == 1 else 'Low Risk'}")
    st.write(f"Risk Probability: {round(probability, 2)}")
```

**Run it in Colab and get a public link:**

```python
!pip install streamlit -q
!nohup streamlit run app.py --server.port 8501 > /content/logs.txt 2>&1 &
import time; time.sleep(10)
!cat /content/logs.txt
!curl -s -o /dev/null -w "%{http_code}" http://localhost:8501   # should print 200

!wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O cloudflared
!chmod +x cloudflared
!nohup ./cloudflared tunnel --url http://localhost:8501 > /content/cf.txt 2>&1 &
import time; time.sleep(15)
!grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' /content/cf.txt
```

The link works only while the Colab session stays open.

## 7. Errors we hit and their causes

| Error | Cause | Fix |
|---|---|---|
| `#N/A` in Excel VLOOKUP | Lookup range not locked | Use `$A$2:$B$11` |
| `MergeError` / `_x`, `_y` columns | Merge cell re-run on an already merged table | Reload `patients`, merge once into `df` |
| `KeyError: 'OutcomeName'` | Column existed in `df`, not in `patients` | Use `df` |
| `KeyError` on features | Column names misspelled or not yet created | Check `df.columns.tolist()` |
| `ValueError` in `plt.plot` | `[0.1]` instead of `[0,1]` | Use `[0, 1], [0, 1]` |
| `AttributeError` in `plt.plot` | `Linestyle` instead of `linestyle` | Keyword arguments are case-sensitive |
| 502 Bad Gateway | Streamlit stopped, or tunnel pointed at the wrong port | Restart Streamlit, tunnel the same port |
| `FileNotFoundError: Risk_model1.pkl` | Model not saved in `/content` | `joblib.dump(model, '/content/Risk_model1.pkl')` |
| `ValueError: feature names` | `LengthOfStay` vs. trained `Lengthofstay` | Match training names exactly |

## 8. Limitations to mention in the report

- The lab values and normal ranges look randomly generated, so lab-based features carry little real signal.
- Expect weak predictive power (AUC near 0.5). The project demonstrates the pipeline and is not a clinical tool.
