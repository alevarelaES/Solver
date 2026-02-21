using System.ComponentModel.DataAnnotations;
using System.Text.RegularExpressions;

namespace Solver.Api.DTOs;

[AttributeUsage(AttributeTargets.Property | AttributeTargets.Parameter)]
public sealed partial class NoHtmlTagsAttribute : ValidationAttribute
{
    [GeneratedRegex(@"<[^>]+>", RegexOptions.Compiled)]
    private static partial Regex HtmlTagPattern();

    protected override ValidationResult? IsValid(object? value, ValidationContext validationContext)
    {
        if (value is string str && HtmlTagPattern().IsMatch(str))
        {
            return new ValidationResult("Field must not contain HTML tags.");
        }

        return ValidationResult.Success;
    }
}
