using EnvDTE;
using Microsoft.VisualStudio.TemplateWizard;
using System.Collections.Generic;

namespace WinAppDriverTestWizard
{
    public class WinAppDriverTestWizard : IWizard
    {
        private TemplateConfig Config;

        public void BeforeOpeningFile(ProjectItem projectItem)
        {

        }

        public void ProjectFinishedGenerating(Project project)
        {
            // TODO: Clear Config and other resources
        }

        public void ProjectItemFinishedGenerating(ProjectItem projectItem)
        {

        }

        public void RunFinished()
        {

        }

        public void RunStarted(object automationObject,
                               Dictionary<string, string> replacementsDictionary,
                               WizardRunKind runKind,
                               object[] customParams)
        {
            // TODO: Do initialization and show the UI
        }

        public bool ShouldAddProjectItem(string filePath)
        {
            return true;
        }
    }
}
